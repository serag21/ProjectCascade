"""Independent cleanup supervisor prototype. LIVE USE IS DISABLED.

No start-play method, desktop input, Studio launch or Studio process termination.
The executable protocol fixture tests this worker in a separate OS process.
An engine-proven identity/resource adapter is still required before live use.
"""
import argparse
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import time
import uuid

LIVE_CERTIFIED = False
MAX_SECONDS = 60
IDENTITY_KEYS = ("studio_id", "pid", "process_created", "image", "place_id", "run_token")


def finite_number(value):
    return type(value) in (int, float) and math.isfinite(value)


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + '.tmp')
    with temporary.open('w', encoding='utf-8') as stream:
        stream.write(json.dumps(value, indent=2, allow_nan=False) + '\n')
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)


def diagnostic(value):
    """The detached launcher retains this separate inherited file descriptor."""
    print(json.dumps(value, allow_nan=False), file=sys.stderr, flush=True)
    try:
        os.fsync(sys.stderr.fileno())
    except (OSError, AttributeError, ValueError):
        pass  # Interactive/captured stderr need not be a regular file.


def distinct_paths(paths, atomic_outputs):
    resolved = [Path(path).resolve() for path in paths]
    resolved += [Path(path).resolve().with_suffix(Path(path).suffix + '.tmp') for path in atomic_outputs]
    if len(set(resolved)) != len(resolved):
        raise ValueError('Refusing overlapping input/evidence/temporary paths')


class Supervisor:
    """Transport functions must be independently bounded, never agent callbacks."""
    def __init__(self, manifest, adapter, log_path, report_path, clock=time.monotonic, sleep=time.sleep, launch_deadline=None):
        self.spec, self.adapter = dict(manifest), adapter
        self.log_path, self.report_path = Path(log_path), Path(report_path)
        self.clock, self.sleep = clock, sleep
        self.events = []
        self.evidence_errors = []
        required = IDENTITY_KEYS
        for key in required:
            value = manifest.get(key)
            if key in ('pid', 'place_id'):
                if type(value) is not int or value < (1 if key == 'pid' else 0):
                    raise ValueError('Invalid exact session identity: ' + key)
            elif not isinstance(value, str) or not value.strip() or len(value) > 1024:
                raise ValueError('Invalid exact session identity: ' + key)
        for key, upper in [('timeout_seconds', MAX_SECONDS), ('poll_seconds', 2),
                           ('call_timeout_seconds', 3), ('cpu_percent_limit', 100),
                           ('rss_mb_limit', 8192)]:
            value = manifest.get(key)
            if not finite_number(value) or not 0 < value <= upper:
                raise ValueError('Invalid bounded limit: ' + key)
        if manifest['poll_seconds'] < .01:
            raise ValueError('Polling interval must be at least 10ms')
        if launch_deadline is not None and (not finite_number(launch_deadline) or launch_deadline < 0):
            raise ValueError('Invalid launcher deadline')
        self.launch_deadline = launch_deadline
        self.identity_keys = required

    def log(self, event, **data):
        entry = dict(event=event, monotonic=self.clock(), utc=datetime.now(timezone.utc).isoformat(), **data)
        self.events.append(entry)
        # Failure to persist evidence must not bypass cleanup of a known session.
        try:
            self.log_path.parent.mkdir(parents=True, exist_ok=True)
            with self.log_path.open('a', encoding='utf-8') as stream:
                stream.write(json.dumps(entry, allow_nan=False) + '\n')
                stream.flush()
                os.fsync(stream.fileno())
        except OSError as error:
            if not self.evidence_errors:
                self.evidence_errors.append('event log: ' + str(error))

    def status(self):
        value = self.adapter('status', self.spec['call_timeout_seconds'])
        if not isinstance(value, dict) or any(type(value.get(key)) is not type(self.spec[key]) or
                value.get(key) != self.spec[key] for key in self.identity_keys):
            raise ValueError('Session identity mismatch; no stop sent')
        if value.get('mode') not in ('Edit', 'Play'):
            raise ValueError('Unknown Studio state')
        return value

    @staticmethod
    def resources_valid(value):
        return all(finite_number(value.get(key)) and value[key] >= 0
                   for key in ('cpu_percent', 'rss_mb'))

    def result(self, status, reason):
        result = dict(status=status, reason=reason, studio_id=self.spec['studio_id'],
                      pid=self.spec['pid'], stopped_verified=status == 'stopped',
                      identity={key:self.spec[key] for key in self.identity_keys},
                      evidence_complete=not self.evidence_errors, evidence_errors=self.evidence_errors,
                      live_certified=False, supervisor_pid=os.getpid(), events=self.events)
        try:
            write_json(self.report_path, result)
        except OSError as error:
            self.evidence_errors.append('final report: ' + str(error))
            result['evidence_complete'] = False
            # Last-resort bounded diagnostic; callers must preserve stderr.
            diagnostic(result)
        return result

    def run(self, on_ready=None):
        deadline = self.clock() + self.spec['timeout_seconds']
        if self.launch_deadline is not None:
            deadline = min(deadline, self.launch_deadline)
        self.log('armed', deadline=deadline, studio_id=self.spec['studio_id'], pid=self.spec['pid'])
        reason = 'deadline'
        acknowledged = False
        while self.clock() < deadline:
            try:
                value = self.status()
            except Exception as error:
                # No identity evidence means no authority to stop anything.
                self.log('inspection_failed', error=str(error))
                return self.result('cleanup_unconfirmed', str(error))
            if value['mode'] == 'Edit':
                return self.result('stopped', 'already stopped')
            if not self.resources_valid(value):
                reason = 'resource monitoring unavailable'
                self.log('resource_sample_invalid')
                break
            self.log('sample', mode=value['mode'], cpu_percent=value['cpu_percent'], rss_mb=value['rss_mb'])
            if self.evidence_errors:
                reason = 'evidence persistence failed'
                break
            if value['cpu_percent'] > self.spec['cpu_percent_limit'] or value['rss_mb'] > self.spec['rss_mb_limit']:
                reason = 'resource budget exceeded'
                break
            if on_ready is not None and not acknowledged:
                try:
                    if self.clock() >= deadline:
                        break
                    on_ready(deadline)
                    acknowledged = True
                except (OSError, ValueError) as error:
                    self.evidence_errors.append('readiness: ' + str(error))
                    reason = 'readiness acknowledgement failed'
                    break
            self.sleep(min(self.spec['poll_seconds'], max(0, deadline-self.clock())))
        # Two finite attempts, fresh identity check before each mutation. Never kill Studio.
        for attempt in range(2):
            try:
                if self.status()['mode'] == 'Edit':
                    return self.result('stopped', reason)
                self.log('normal_stop_requested', attempt=attempt+1, reason=reason)
                self.adapter('stop', self.spec['call_timeout_seconds'],
                             {key:self.spec[key] for key in self.identity_keys})
                if self.status()['mode'] == 'Edit':
                    self.log('stopped_verified')
                    return self.result('stopped', reason)
                self.log('stop_not_verified')
            except Exception as error:
                self.log('cleanup_failed', error=str(error))
                # Identity may have changed. A later attempt must revalidate it.
        return self.result('cleanup_unconfirmed', reason)


class FixtureAdapter:
    """OS subprocess protocol double, not a Studio connection.

    Each request has a hard subprocess deadline. Only this child Python process
    may be killed by subprocess.run on timeout. It cannot launch/terminate Studio.
    """
    def __init__(self, state_path):
        self.state_path = str(Path(state_path).resolve())

    def __call__(self, operation, timeout, expected_identity=None):
        response = subprocess.run([sys.executable, str(Path(__file__).resolve()),
                                   '_fixture-request', self.state_path, operation, json.dumps(expected_identity)],
                                  capture_output=True, text=True, timeout=timeout,
                                  creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        if response.returncode:
            raise RuntimeError('fixture transport failed: ' + response.stderr[-300:])
        return json.loads(response.stdout)


def fixture_request(path, operation, expected_identity=None):
    value = json.loads(Path(path).read_text(encoding='utf-8'))
    if value.get('hang') == operation:
        time.sleep(5)
    if operation == 'stop':
        # Recheck at mutation time, not merely the previous observation. This is
        # only a fixture contract; real bridge atomic binding is still unproven.
        if not isinstance(expected_identity, dict) or any(
                type(value.get(key)) is not type(expected_identity.get(key)) or
                value.get(key) != expected_identity.get(key) for key in IDENTITY_KEYS):
            raise ValueError('Stop identity changed; refusing mutation')
        value['stop_requests'] = value.get('stop_requests', 0) + 1
        if not value.get('ignore_stop'):
            value['mode'] = 'Edit'
        write_json(path, value)
    print(json.dumps(value))


class FixtureReadinessError(RuntimeError):
    def __init__(self, message, worker):
        super().__init__(message)
        self.worker = worker  # Exact disposable child handle for fixture callers to reap.


def launch_fixture_worker(manifest, state, log, report, *, ready=None, diagnostics=None, ready_timeout=2):
    """Return only after THIS fixture worker acknowledges arming; never starts Studio.

    Readiness failure raises and does not kill the independent cleanup worker.
    The worker still owns its original short deadline, even after launcher exit.
    """
    if not finite_number(ready_timeout) or not 0 < ready_timeout <= 3:
        raise ValueError('Readiness timeout must be positive and <=3 seconds')
    manifest, state, log, report = [Path(path).resolve() for path in (manifest, state, log, report)]
    ready = Path(ready).resolve() if ready else Path(str(report) + '.ready.json')
    diagnostics = Path(diagnostics).resolve() if diagnostics else Path(str(report) + '.diagnostic.jsonl')
    distinct_paths([manifest, state, log, report, ready, diagnostics], [report, ready, state])
    spec = json.loads(Path(manifest).read_text(encoding='utf-8'))
    Supervisor(spec, None, log, report)  # Validate before detaching.
    deadline = time.monotonic() + spec['timeout_seconds']
    nonce = uuid.uuid4().hex
    flags = (getattr(subprocess, 'CREATE_NO_WINDOW', 0) |
             getattr(subprocess, 'CREATE_NEW_PROCESS_GROUP', 0))
    diagnostics.parent.mkdir(parents=True, exist_ok=True)
    # Open before spawning. If the fallback sink is unavailable, create no worker.
    with diagnostics.open('a', encoding='utf-8') as sink:
        sink.write(json.dumps({'event':'launch_requested', 'nonce':nonce, 'deadline':deadline})+'\n')
        sink.flush(); os.fsync(sink.fileno())
        process = subprocess.Popen([sys.executable, str(Path(__file__).resolve()),
            'fixture-worker', '--manifest', str(manifest), '--state', str(state),
            '--log', str(log), '--report', str(report), '--deadline-monotonic', str(deadline),
            '--ready', str(ready), '--ready-nonce', nonce], stdin=subprocess.DEVNULL,
            stdout=sink, stderr=sink, close_fds=True,
            creationflags=flags, start_new_session=os.name != 'nt')
    until = min(deadline, time.monotonic()+ready_timeout)
    while time.monotonic() < until:
        try:
            ack = json.loads(ready.read_text(encoding='utf-8'))
            if (ack.get('nonce') == nonce and ack.get('supervisor_pid') == process.pid
                    and ack.get('deadline') == deadline
                    and ack.get('identity') == {key:spec[key] for key in IDENTITY_KEYS}
                    and process.poll() is None):
                return process
        except (OSError, ValueError):
            pass
        if process.poll() is not None:
            break
        time.sleep(.01)
    raise FixtureReadinessError('Fixture worker readiness unconfirmed; no launch authorized. '
                       'Independent cleanup continues until its original deadline; inspect '+str(diagnostics), process)


def main():
    if len(sys.argv) > 1 and sys.argv[1] == '_fixture-request':
        fixture_request(sys.argv[2], sys.argv[3], json.loads(sys.argv[4])); return
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['status', 'live', 'fixture-worker'])
    for key in ('manifest', 'state', 'log', 'report'):
        parser.add_argument('--' + key)
    parser.add_argument('--deadline-monotonic', type=float)
    parser.add_argument('--ready')
    parser.add_argument('--ready-nonce')
    args = parser.parse_args()
    if args.mode == 'status':
        print(json.dumps({'unattended_enabled': False, 'live_certified': LIVE_CERTIFIED,
                          'reason': 'No engine-proven process binding, GPU monitor or hung-Studio cleanup'}))
        return
    if args.mode == 'live':
        parser.exit(2, 'DISABLED: live supervision/testing is not certified or owner-authorized.\n')
    if not all((args.manifest, args.state, args.log, args.report)):
        parser.error('fixture-worker requires manifest/state/log/report')
    paths = [value for value in (args.manifest, args.state, args.log, args.report, args.ready) if value]
    try:
        distinct_paths(paths, [value for value in (args.report, args.state, args.ready) if value])
    except ValueError as error:
        parser.exit(2, str(error)+'\n')
    try:
        spec = json.loads(Path(args.manifest).read_text(encoding='utf-8'))
        if bool(args.ready) != bool(args.ready_nonce):
            raise ValueError('Readiness path and nonce must be supplied together')
        def acknowledge(deadline):
            ack = dict(nonce=args.ready_nonce, supervisor_pid=os.getpid(), deadline=deadline,
                       identity={key:spec[key] for key in IDENTITY_KEYS}, live_certified=False)
            write_json(args.ready, ack)
            diagnostic(dict(event='fixture_ready', **ack))
        outcome = Supervisor(spec, FixtureAdapter(args.state), args.log, args.report,
                             launch_deadline=args.deadline_monotonic).run(acknowledge if args.ready else None)
    except (OSError, ValueError, TypeError) as error:
        # Startup validation never acquires authority for a stop operation.
        outcome = dict(status='startup_failed', reason=str(error), stopped_verified=False,
                       live_certified=False, evidence_complete=False, supervisor_pid=os.getpid())
        try:
            write_json(args.report, outcome)
        except OSError as report_error:
            outcome['report_error'] = str(report_error)
    diagnostic(outcome)
    raise SystemExit(0 if outcome['stopped_verified'] and outcome['evidence_complete'] else 1)


if __name__ == '__main__':
    main()
