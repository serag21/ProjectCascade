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
            print(json.dumps(result), file=sys.stderr, flush=True)
        return result

    def run(self):
        deadline = self.clock() + self.spec['timeout_seconds']
        if self.launch_deadline is not None:
            deadline = min(deadline, self.launch_deadline)
        self.log('armed', deadline=deadline, studio_id=self.spec['studio_id'], pid=self.spec['pid'])
        reason = 'deadline'
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


def launch_fixture_worker(manifest, state, log, report):
    """Detach a TEST-ONLY worker. It lives beyond its launcher and never starts Studio."""
    spec = json.loads(Path(manifest).read_text(encoding='utf-8'))
    Supervisor(spec, None, log, report)  # Validate before detaching.
    deadline = time.monotonic() + spec['timeout_seconds']
    flags = (getattr(subprocess, 'CREATE_NO_WINDOW', 0) |
             getattr(subprocess, 'CREATE_NEW_PROCESS_GROUP', 0))
    return subprocess.Popen([sys.executable, str(Path(__file__).resolve()),
        'fixture-worker', '--manifest', str(manifest), '--state', str(state),
        '--log', str(log), '--report', str(report), '--deadline-monotonic', str(deadline)], stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, close_fds=True,
        creationflags=flags, start_new_session=os.name != 'nt')


def main():
    if len(sys.argv) > 1 and sys.argv[1] == '_fixture-request':
        fixture_request(sys.argv[2], sys.argv[3], json.loads(sys.argv[4])); return
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['status', 'live', 'fixture-worker'])
    for key in ('manifest', 'state', 'log', 'report'):
        parser.add_argument('--' + key)
    parser.add_argument('--deadline-monotonic', type=float)
    args = parser.parse_args()
    if args.mode == 'status':
        print(json.dumps({'unattended_enabled': False, 'live_certified': LIVE_CERTIFIED,
                          'reason': 'No engine-proven process binding, GPU monitor or hung-Studio cleanup'}))
        return
    if args.mode == 'live':
        parser.exit(2, 'DISABLED: live supervision/testing is not certified or owner-authorized.\n')
    if not all((args.manifest, args.state, args.log, args.report)):
        parser.error('fixture-worker requires manifest/state/log/report')
    paths = [Path(value).resolve() for value in (args.manifest, args.state, args.log, args.report)]
    if len(set(paths)) != 4:
        parser.exit(2, 'Refusing overlapping manifest/state/evidence paths. No action taken.\n')
    try:
        spec = json.loads(Path(args.manifest).read_text(encoding='utf-8'))
        outcome = Supervisor(spec, FixtureAdapter(args.state), args.log, args.report,
                             launch_deadline=args.deadline_monotonic).run()
    except (OSError, ValueError, TypeError) as error:
        # Startup validation never acquires authority for a stop operation.
        outcome = dict(status='startup_failed', reason=str(error), stopped_verified=False,
                       live_certified=False, evidence_complete=False, supervisor_pid=os.getpid())
        try:
            write_json(args.report, outcome)
        except OSError as report_error:
            outcome['report_error'] = str(report_error)
        print(json.dumps(outcome), file=sys.stderr, flush=True)
    raise SystemExit(0 if outcome['stopped_verified'] and outcome['evidence_complete'] else 1)


if __name__ == '__main__':
    main()
