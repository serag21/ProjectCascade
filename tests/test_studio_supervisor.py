"""Independent worker tests with lightweight subprocess fixtures; never starts Studio."""
import importlib.util
import contextlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / 'tools/studio_supervisor.py'
spec = importlib.util.spec_from_file_location('supervisor', MODULE)
supervisor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(supervisor)


class Tests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.manifest = dict(studio_id='fixture-only', pid=123, process_created='exact-start',
            image='fixture-not-Studio', place_id=127090454461830, run_token='test-token',
            timeout_seconds=.3, poll_seconds=.04, call_timeout_seconds=.2,
            cpu_percent_limit=25, rss_mb_limit=1024)
        self.state = dict(self.manifest, mode='Play', cpu_percent=0, rss_mb=10)

    def tearDown(self):
        self.tmp.cleanup()

    def run_case(self, patch=None):
        state = dict(self.state, **(patch or {}))
        path = self.root/'state.json'
        supervisor.write_json(path, state)
        worker = supervisor.Supervisor(self.manifest, supervisor.FixtureAdapter(path),
                                       self.root/'log.jsonl', self.root/'report.json')
        return worker.run(), json.loads(path.read_text())

    def test_deadline_normal_stop_and_verify(self):
        result, state = self.run_case()
        self.assertTrue(result['stopped_verified'])
        self.assertEqual(state['stop_requests'], 1)

    def test_pid_reuse_and_wrong_studio_never_stopped(self):
        for patch in ({'pid':124}, {'process_created':'new'}, {'studio_id':'other'},
                      {'run_token':'other'}, {'image':'other'}, {'place_id':1}):
            result, state = self.run_case(patch)
            self.assertFalse(result['stopped_verified'])
            self.assertNotIn('stop_requests', state)

    def test_resource_budget_requests_early_stop(self):
        result, _ = self.run_case({'cpu_percent':80})
        self.assertEqual(result['reason'], 'resource budget exceeded')
        result, _ = self.run_case({'rss_mb':2048})
        self.assertTrue(result['stopped_verified'])

    def test_stop_ack_is_not_stopped_evidence(self):
        result, state = self.run_case({'ignore_stop':True})
        self.assertFalse(result['stopped_verified'])
        self.assertEqual(state['stop_requests'], 2)

    def test_hung_status_or_stop_is_bounded_and_reported(self):
        for operation in ('status', 'stop'):
            before = time.monotonic()
            result, _ = self.run_case({'hang':operation})
            self.assertFalse(result['stopped_verified'])
            self.assertLess(time.monotonic()-before, 3)

    def test_already_stopped_does_not_mutate(self):
        result, state = self.run_case({'mode':'Edit'})
        self.assertTrue(result['stopped_verified'])
        self.assertNotIn('stop_requests', state)

    def test_invalid_or_unbounded_manifest(self):
        for key, value in [('timeout_seconds',3600), ('timeout_seconds',float('nan')),
                           ('poll_seconds',0), ('run_token','')]:
            with self.assertRaises(ValueError):
                supervisor.Supervisor(dict(self.manifest, **{key:value}), None, '', '')

    def test_strict_identity_and_limits_reject_bool_and_invalid_types(self):
        for key, value in [('pid', True), ('pid', '123'), ('place_id', -1),
                           ('studio_id', ['fixture-only']), ('timeout_seconds', True),
                           ('poll_seconds', .00001), ('rss_mb_limit', float('inf'))]:
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                supervisor.Supervisor(dict(self.manifest, **{key:value}), None, '', '')
        # Local unpublished places have ID 0 and are valid exact identities.
        supervisor.Supervisor(dict(self.manifest, place_id=0), None, '', '')

    def test_missing_resources_still_stop_exact_known_session(self):
        for patch in ({'cpu_percent':None}, {'rss_mb':-1}, {'cpu_percent':True}):
            result, state = self.run_case(patch)
            self.assertTrue(result['stopped_verified'])
            self.assertEqual(result['reason'], 'resource monitoring unavailable')
            self.assertEqual(state['stop_requests'], 1)

    def test_edit_verification_does_not_depend_on_resource_sampler(self):
        result, state = self.run_case({'mode':'Edit', 'cpu_percent':None})
        self.assertTrue(result['stopped_verified'])
        self.assertNotIn('stop_requests', state)

    def test_logging_failure_does_not_skip_cleanup(self):
        path = self.root/'state.json'
        supervisor.write_json(path, self.state)
        blocked = self.root/'blocked'
        blocked.write_text('not a directory')
        worker = supervisor.Supervisor(self.manifest, supervisor.FixtureAdapter(path),
                                       blocked/'log', self.root/'report.json')
        result = worker.run()
        self.assertTrue(result['stopped_verified'])
        self.assertFalse(result['evidence_complete'])
        self.assertEqual(result['reason'], 'evidence persistence failed')
        self.assertTrue(result['evidence_errors'])

    def test_delayed_worker_does_not_reset_session_budget(self):
        path = self.root/'state.json'
        supervisor.write_json(path, self.state)
        worker = supervisor.Supervisor(dict(self.manifest, timeout_seconds=60),
            supervisor.FixtureAdapter(path), self.root/'log', self.root/'report',
            launch_deadline=time.monotonic()-.01)
        started = time.monotonic()
        result = worker.run()
        self.assertTrue(result['stopped_verified'])
        self.assertLess(time.monotonic()-started, 2)
        self.assertFalse(any(e['event']=='sample' for e in result['events']))

    def test_manifest_cannot_be_mutated_after_arming(self):
        path = self.root/'state.json'
        supervisor.write_json(path, self.state)
        worker = supervisor.Supervisor(self.manifest, supervisor.FixtureAdapter(path),
                                       self.root/'log', self.root/'report')
        self.manifest['pid'] = 999
        self.assertTrue(worker.run()['stopped_verified'])

    def test_identity_change_between_inspection_and_stop_refuses_mutation(self):
        path = self.root/'state.json'
        supervisor.write_json(path, self.state)
        adapter = supervisor.FixtureAdapter(path)
        def racing_adapter(operation, timeout, identity=None):
            if operation == 'stop':
                changed = json.loads(path.read_text())
                changed['process_created'] = 'reused-process'
                supervisor.write_json(path, changed)
            return adapter(operation, timeout, identity)
        result = supervisor.Supervisor(self.manifest, racing_adapter,
            self.root/'log', self.root/'report', launch_deadline=0).run()
        self.assertFalse(result['stopped_verified'])
        self.assertNotIn('stop_requests', json.loads(path.read_text()))

    def test_report_failure_is_explicit_after_successful_cleanup(self):
        path = self.root/'state.json'
        supervisor.write_json(path, self.state)
        blocked = self.root/'blocked'
        blocked.write_text('not a directory')
        diagnostics = io.StringIO()
        with contextlib.redirect_stderr(diagnostics):
            result = supervisor.Supervisor(self.manifest, supervisor.FixtureAdapter(path),
                self.root/'log', blocked/'report').run()
        self.assertTrue(result['stopped_verified'])
        self.assertFalse(result['evidence_complete'])
        self.assertIn('final report', diagnostics.getvalue())

    def test_invalid_worker_startup_reports_without_mutation(self):
        paths = [self.root/name for name in ('manifest.json','state.json','log','report')]
        supervisor.write_json(paths[0], dict(self.manifest, pid=True))
        supervisor.write_json(paths[1], self.state)
        result = subprocess.run([sys.executable,str(MODULE),'fixture-worker',
            '--manifest',str(paths[0]),'--state',str(paths[1]),
            '--log',str(paths[2]),'--report',str(paths[3])], capture_output=True,text=True,timeout=2)
        self.assertEqual(result.returncode,1)
        self.assertEqual(json.loads(paths[3].read_text())['status'],'startup_failed')
        self.assertNotIn('stop_requests',json.loads(paths[1].read_text()))

    def test_live_capability_is_disabled(self):
        result = subprocess.run([sys.executable,str(MODULE),'live'],capture_output=True,text=True)
        self.assertEqual(result.returncode,2)
        self.assertIn('DISABLED',result.stderr)

    def fixture_paths(self, timeout=.8):
        paths=[self.root/name for name in ('manifest.json','state.json','log.jsonl','report.json')]
        supervisor.write_json(paths[0],dict(self.manifest,timeout_seconds=timeout))
        supervisor.write_json(paths[1],self.state)
        return paths

    def test_launcher_returns_only_matching_worker_readiness(self):
        paths=self.fixture_paths()
        process=supervisor.launch_fixture_worker(*paths)
        ack=json.loads(Path(str(paths[3])+'.ready.json').read_text())
        self.assertEqual(ack['supervisor_pid'],process.pid)
        self.assertEqual(ack['identity'],{key:self.manifest[key] for key in supervisor.IDENTITY_KEYS})
        self.assertFalse(ack['live_certified'])
        self.assertIsNone(process.poll())
        process.wait(timeout=3)
        diagnostic=Path(str(paths[3])+'.diagnostic.jsonl').read_text()
        self.assertIn('fixture_ready',diagnostic)
        self.assertIn('"stopped_verified": true',diagnostic)

    def test_stale_ack_cannot_authorize_wrong_session(self):
        paths=self.fixture_paths()
        supervisor.write_json(Path(str(paths[3])+'.ready.json'),dict(nonce='stale',supervisor_pid=123))
        supervisor.write_json(paths[1],dict(self.state,run_token='wrong-session'))
        with self.assertRaisesRegex(RuntimeError,'readiness unconfirmed'):
            supervisor.launch_fixture_worker(*paths)
        self.assertNotIn('stop_requests',json.loads(paths[1].read_text()))
        diagnostic=Path(str(paths[3])+'.diagnostic.jsonl').read_text()
        self.assertIn('cleanup_unconfirmed',diagnostic)

    def test_readiness_write_failure_still_cleans_up(self):
        paths=self.fixture_paths()
        blocked=self.root/'blocked';blocked.write_text('not a directory')
        with self.assertRaisesRegex(RuntimeError,'readiness unconfirmed'):
            supervisor.launch_fixture_worker(*paths,ready=blocked/'ready.json')
        report=json.loads(paths[3].read_text())
        self.assertTrue(report['stopped_verified'])
        self.assertFalse(report['evidence_complete'])
        self.assertEqual(report['reason'],'readiness acknowledgement failed')

    def test_diagnostics_survive_primary_log_and_report_failure(self):
        manifest,state,_,_=self.fixture_paths()
        blocked=self.root/'blocked';blocked.write_text('not a directory')
        sink=self.root/'independent'/'diagnostic.jsonl'
        with self.assertRaisesRegex(RuntimeError,'readiness unconfirmed'):
            supervisor.launch_fixture_worker(manifest,state,blocked/'log',blocked/'report',
                ready=self.root/'ready.json',diagnostics=sink)
        output=sink.read_text()
        self.assertIn('"stopped_verified": true',output)
        self.assertIn('final report',output)
        self.assertEqual(json.loads(state.read_text())['mode'],'Edit')

    def test_diagnostic_failure_and_path_alias_fail_before_spawning(self):
        paths=self.fixture_paths()
        blocked=self.root/'blocked';blocked.write_text('not a directory')
        with self.assertRaises(OSError):
            supervisor.launch_fixture_worker(*paths,diagnostics=blocked/'sink')
        with self.assertRaises(ValueError):
            supervisor.launch_fixture_worker(*paths,diagnostics=paths[1])
        with self.assertRaises(ValueError):
            supervisor.launch_fixture_worker(*paths,ready=str(paths[1])+'.tmp')
        self.assertNotIn('stop_requests',json.loads(paths[1].read_text()))

    def test_readiness_wait_is_bounded_without_killing_cleanup_worker(self):
        paths=self.fixture_paths(timeout=.5)
        before=time.monotonic()
        with self.assertRaisesRegex(RuntimeError,'readiness unconfirmed'):
            supervisor.launch_fixture_worker(*paths,ready_timeout=.001)
        self.assertLess(time.monotonic()-before,1)
        deadline=time.monotonic()+3
        while not paths[3].exists() and time.monotonic()<deadline: time.sleep(.02)
        self.assertTrue(json.loads(paths[3].read_text())['stopped_verified'])

    def test_worker_survives_launcher_exit(self):
        paths = [self.root/name for name in ('manifest.json','state.json','log.jsonl','report.json')]
        supervisor.write_json(paths[0], dict(self.manifest,timeout_seconds=.7))
        supervisor.write_json(paths[1], self.state)
        # The launcher exits immediately: independent worker still must stop and report.
        code = ('import sys;sys.path.insert(0,sys.argv[1]);import studio_supervisor as s;'
                's.launch_fixture_worker(*sys.argv[2:])')
        launch = subprocess.run([sys.executable,'-c',code,str(ROOT/'tools'),*map(str,paths)],
                                capture_output=True,text=True,timeout=3)
        self.assertEqual(launch.returncode,0,launch.stderr)
        deadline = time.monotonic()+5
        while not paths[3].exists() and time.monotonic()<deadline:
            time.sleep(.05)
        self.assertTrue(paths[3].exists(),'Independent worker did not report after launcher exited')
        result=json.loads(paths[3].read_text())
        self.assertTrue(result['stopped_verified'])
        self.assertEqual(json.loads(paths[1].read_text())['mode'],'Edit')

    def test_worker_survives_launcher_termination(self):
        paths = [self.root/name for name in ('manifest.json','state.json','log.jsonl','report.json')]
        supervisor.write_json(paths[0], dict(self.manifest,timeout_seconds=.8))
        supervisor.write_json(paths[1], self.state)
        code = ('import sys,time;sys.path.insert(0,sys.argv[1]);import studio_supervisor as s;'
                's.launch_fixture_worker(*sys.argv[2:]);time.sleep(5)')
        launcher = subprocess.Popen([sys.executable,'-c',code,str(ROOT/'tools'),*map(str,paths)],
                                    creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        try:
            deadline=time.monotonic()+3
            while not paths[2].exists() and time.monotonic()<deadline: time.sleep(.02)
            self.assertTrue(paths[2].exists(),'Worker must be armed before simulated interruption')
        finally:
            # Only this newly created disposable Python launcher; never any Studio/app.
            launcher.terminate(); launcher.wait(timeout=2)
        deadline=time.monotonic()+5
        while not paths[3].exists() and time.monotonic()<deadline: time.sleep(.05)
        self.assertTrue(paths[3].exists())
        self.assertTrue(json.loads(paths[3].read_text())['stopped_verified'])


if __name__ == '__main__':
    unittest.main()
