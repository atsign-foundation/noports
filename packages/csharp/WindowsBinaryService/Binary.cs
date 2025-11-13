// Wrapper for a binary
// Runs the provided binary as a subprocess

using System.Diagnostics;
using System.Text;
using System.Threading.Channels;

namespace WindowsBinaryService
{
	internal class Binary
	{
		private ProcessStartInfo startInfo;
		private ILogger logger;
		private Channel<string> logChannel;
		private bool shouldClose = false;
		private Task logDebouncer;

		private Process? process;

		public Binary(string path, ILogger logger)
		{
			this.logger = logger;
			startInfo = new ProcessStartInfo
			{
				CreateNoWindow = true,
				UseShellExecute = false,
				FileName = path,
				Arguments = string.Join(" ", Environment.GetCommandLineArgs().Skip(1)),
				WindowStyle = ProcessWindowStyle.Hidden,
				RedirectStandardError = true,
				RedirectStandardOutput = true,
			};
			logChannel = Channel.CreateUnbounded<string>();
			logDebouncer = Task.Run(() => LogDebouncer());
		}

		public async Task Run(CancellationToken ct)
		{
			try
			{
				process = Process.Start(startInfo);
				if (process == null)
				{
					logger.LogCritical($"Host failed to start the {ServiceConfig.Binary} process.\nCheck your installation or contact support.");
					return;
				}
				process.OutputDataReceived += CreateLogHandler();
				process.ErrorDataReceived += CreateLogHandler();

				process.BeginOutputReadLine();
				process.BeginErrorReadLine();

				await process.WaitForExitAsync(ct);
			}
			catch (Exception ex) when (ex is not TaskCanceledException)
			{
				logger.LogCritical(ex.Message);
			}
			finally
			{
				await Stop();
				process = null;
			}
		}

		public async Task Stop()
		{
			if (process != null && !process.HasExited)
			{
				process.Kill();
			}
			logChannel.Writer.TryComplete();
			shouldClose = true;
			await logDebouncer;
		}

		private DataReceivedEventHandler CreateLogHandler()
		{
			return (object sender, DataReceivedEventArgs ev) =>
			{
				if (!string.IsNullOrEmpty(ev.Data))
				{
					logChannel.Writer.TryWrite(ev.Data);
				}
			};
		}

		// Debounces logs by grouping based on time.
		private void LogDebouncer()
		{
			// How much time must elapse between reads before a flush is allowed to happen
			var minReadTimeSpan = TimeSpan.FromMilliseconds(500); 
			// How much time between flushes before we force flush
			var maxFlushTimeSpan = TimeSpan.FromMilliseconds(5000);
			bool didReadLine;
			var logBuffer = new StringBuilder();
			var r = logChannel.Reader;
			var lastFlushTime = DateTime.UtcNow;
			var lastReadTime = DateTime.UtcNow;

			do
			{
				// Read until the following conditions are met:
				// - We have read logs into the buffer AND either of the two are true:
				//   - maxFlushTimeSpan has passed
				//   - there was nothing to read during the last attempt
				do 

				{ 
					didReadLine = r.TryRead(out var line);
					if (didReadLine)
					{
						logBuffer.AppendLine(line);
						lastReadTime = DateTime.UtcNow;
					} else if (logBuffer.Length == 0)
					{
						lastFlushTime = DateTime.UtcNow;
					}

					// Force a flush if we've exceeded the maxFlushTimeSpan
					if (logBuffer.Length > 0 && DateTime.UtcNow - lastFlushTime > maxFlushTimeSpan) break;
					if (shouldClose && r.Count == 0)
					{
						if (logBuffer.Length == 0) return;
						break;
					}
				}
				while (
					logBuffer.Length == 0 || // Don't flush if there's nothing in the buffer 
					didReadLine ||           // We just read a line so keep trying to read
					DateTime.UtcNow - lastReadTime < minReadTimeSpan  // min read time hasn't elapsed
				);

				logger.LogWarning($"{logBuffer}");
				logBuffer.Clear();
				lastFlushTime = DateTime.UtcNow;
				lastReadTime = DateTime.UtcNow;
			} while (!shouldClose || r.Count > 0);
		}
	}

}
