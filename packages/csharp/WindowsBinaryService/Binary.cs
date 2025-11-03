// Wrapper for a binary
// Runs the provided binary as a subprocess

using System.Diagnostics;
using System.Text;
using System.Threading.Channels;

namespace WindowsBinaryService
{
    internal class Binary
    {
        private readonly string _path;
        private Process? _process;
        private ILogger _logger;
        public Binary(string path, ILogger logger)
        {
            _path = path;
            _logger = logger;
        }

        public async Task RunBinary(CancellationToken cancellationToken)
        {
            // Use ProcessStartInfo class
            ProcessStartInfo startInfo = new();
            startInfo.CreateNoWindow = false;
            startInfo.UseShellExecute = false;
            startInfo.FileName = _path;
            startInfo.WindowStyle = ProcessWindowStyle.Hidden;
            startInfo.RedirectStandardOutput = true;
            startInfo.RedirectStandardError = true;

            try
            {
                _process = Process.Start(startInfo)!;
                using (_process)
                {
                    var outputChannel = Channel.CreateUnbounded<string>();
                    var errorChannel = Channel.CreateUnbounded<string>();

                    // Background tasks to process channels


                    //lowkey only the stderr channel matters ngl (idk why sshnp doesnt pipe any stdout)
                    var outputTask = ProcessChannelAsync(outputChannel.Reader, cancellationToken);
                    var errorTask = ProcessChannelAsync(errorChannel.Reader, cancellationToken);

                    async Task ProcessChannelAsync(ChannelReader<string> reader, CancellationToken ct)
                    {
                        var chunk = new StringBuilder();
                        var lastFlush = DateTime.UtcNow;

                        await foreach (var line in reader.ReadAllAsync(ct))
                        {
                            chunk.AppendLine(line);

                            // Flush if chunk is large enough or enough time has passed
                            if (DateTime.UtcNow - lastFlush > TimeSpan.FromMilliseconds(5000))
                            {
                                _logger.LogWarning($"{chunk}");
                                chunk.Clear();
                                lastFlush = DateTime.UtcNow;
                            }
                        }

                        // Final flush
                        if (chunk.Length > 0)
                        {
                            _logger.LogError($"sshnpd process closing, final log: {chunk}");
                        }
                    }

                    _process.OutputDataReceived += (sender, e) =>
                    {
                        if (!string.IsNullOrEmpty(e.Data))
                        {
                            outputChannel.Writer.TryWrite(e.Data);
                        }
                    };

                    _process.ErrorDataReceived += (sender, e) =>
                    {
                        if (!string.IsNullOrEmpty(e.Data))
                        {
                            errorChannel.Writer.TryWrite(e.Data);
                        }
                    };

                    // Optionally, start reading output/error here if needed:
                    _process.BeginOutputReadLine();
                    _process.BeginErrorReadLine();

                    // Wait for process to exit
                    await _process.WaitForExitAsync(cancellationToken);

                    // Complete the channels to finish the background tasks
                    outputChannel.Writer.Complete();
                    errorChannel.Writer.Complete();

                    await Task.WhenAll(outputTask, errorTask);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Exception starting process: {ex.Message}");
                throw;
            }
        }

        public void Stop()
        {
            if (_process != null && !_process.HasExited)
            {
                _process.Kill();
            }
        }

        public async Task WaitForExit()
        {
            if (_process != null && !_process.HasExited)
            {
                try
                {
                    await _process.WaitForExitAsync();
                }
                catch { } // Ignore exceptions on closing the process (cancellationToken might dispose of _process before this is called)
            }
        }
    }
}
