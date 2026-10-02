"""App Server newline JSON transport. Never retries uncertain mutations."""

import asyncio
import json


class TransportLost(RuntimeError):
    """The peer disconnected or timed out; operation outcome may be unknown."""


class RequestRejected(RuntimeError):
    def __init__(self, error):
        self.error = error
        super().__init__(str(error.get('message', 'App Server rejected request')))


class AppServer:
    @classmethod
    async def open(cls, argv, on_message):
        # stderr stays separate from the MCP stdout stream. No shell interpolation.
        process = await asyncio.create_subprocess_exec(
            *argv, stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE, limit=8 * 1024 * 1024)
        return cls(process, on_message)

    def __init__(self, process, on_message):
        self.process = process
        self.on_message = on_message
        self.pending = {}
        self.serial = 0
        self.alive = True
        self.writer_lock = asyncio.Lock()
        self.reader = asyncio.create_task(self._read())

    async def _read(self):
        try:
            while True:
                line = await self.process.stdout.readline()
                if not line:
                    break
                message = json.loads(line)
                if not isinstance(message, dict):
                    raise ValueError('App Server returned a non-object message')
                if 'method' in message:
                    self.on_message(message)
                else:
                    future = self.pending.get(message.get('id'))
                    if future is not None and not future.done():
                        if 'error' in message:
                            future.set_exception(RequestRejected(message['error']))
                        elif 'result' in message:
                            future.set_result(message['result'])
                        else:
                            raise ValueError('App Server response has no result/error')
        except (ValueError, OSError, asyncio.CancelledError) as exc:
            reason = type(exc).__name__
        else:
            reason = 'EOF'
        finally:
            self.alive = False
            error = TransportLost('App Server connection lost; outcome unknown')
            for future in self.pending.values():
                if not future.done():
                    future.set_exception(error)
            self.on_message({'method': 'adapter/connectionLost',
                             'params': {'reason': locals().get('reason', 'reader failure')}})

    async def send(self, message):
        if not self.alive:
            raise TransportLost('App Server disconnected; no automatic replay')
        async with self.writer_lock:
            try:
                self.process.stdin.write((json.dumps(message) + '\n').encode())
                await self.process.stdin.drain()
            except (OSError, ConnectionError) as exc:
                raise TransportLost('App Server write failed; outcome unknown') from exc

    async def call(self, method, params=None, timeout=30):
        self.serial += 1
        request_id = self.serial
        future = asyncio.get_running_loop().create_future()
        self.pending[request_id] = future
        try:
            await self.send({'id': request_id, 'method': method,
                             'params': params or {}})
            try:
                return await asyncio.wait_for(future, timeout)
            except asyncio.TimeoutError as exc:
                raise TransportLost('App Server response timed out; outcome unknown, do not replay') from exc
        finally:
            self.pending.pop(request_id, None)

    async def close(self):
        # Closing the process is not evidence that any external action rolled back.
        if self.process.returncode is None:
            self.process.stdin.close()
            try:
                await asyncio.wait_for(self.process.wait(), 3)
            except asyncio.TimeoutError:
                self.process.terminate()
                try:
                    await asyncio.wait_for(self.process.wait(), 3)
                except asyncio.TimeoutError:
                    self.process.kill()
                    await self.process.wait()
        await self.reader
