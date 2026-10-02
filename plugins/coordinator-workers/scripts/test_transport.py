import asyncio
import json
import sys
import unittest

from transport import AppServer, TransportLost, RequestRejected


# Controlled peer for adapter failure handling; no Codex contract reimplementation.
PEER = '''
import sys,json
for line in sys.stdin:
    m=json.loads(line)
    if 'id' not in m: continue
    if m.get('method') == 'exit': sys.exit(0)
    if m.get('method') == 'reject':
        print(json.dumps({'id':m['id'],'error':{'code':-1,'message':'denied'}}),flush=True)
        continue
    print(json.dumps({'method':'turn/completed','params':{'threadId':'worker'}}),flush=True)
    print(json.dumps({'id':'approval-1','method':'item/fileChange/requestApproval','params':{'threadId':'worker'}}),flush=True)
    print(json.dumps({'id':m['id'],'result':m.get('params',{})}),flush=True)
'''


class TransportTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.messages = []
        self.server = await AppServer.open(
            [sys.executable, '-u', '-c', PEER], self.messages.append)

    async def asyncTearDown(self):
        await self.server.close()

    async def test_interleaved_events_and_requests_are_not_lost(self):
        result = await self.server.call('echo', {'cwd': '/assigned'})
        self.assertEqual(result, {'cwd': '/assigned'})
        self.assertEqual(self.messages[0]['method'], 'turn/completed')
        self.assertEqual(self.messages[1]['id'], 'approval-1')

    async def test_concurrent_responses_keep_identity(self):
        results = await asyncio.gather(*[
            self.server.call('echo', {'number': n}) for n in range(4)])
        self.assertEqual(results, [{'number': n} for n in range(4)])

    async def test_rejection_is_not_transport_loss(self):
        with self.assertRaises(RequestRejected) as caught:
            await self.server.call('reject')
        self.assertIn('denied', str(caught.exception))
        self.assertTrue(self.server.alive)

    async def test_disconnect_marks_inflight_outcome_unknown(self):
        with self.assertRaises(TransportLost):
            await self.server.call('exit')
        self.assertFalse(self.server.alive)


if __name__ == '__main__':
    unittest.main()
