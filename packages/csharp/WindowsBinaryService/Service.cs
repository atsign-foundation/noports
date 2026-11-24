// The Windows BackgroundService interface
// This starts up the appropriate dart binary

namespace WindowsBinaryService
{
	public class Service : BackgroundService
	{

		private readonly ILogger<Service> _logger;
#if DEBUG
		private const string _directory = "C:\\Program Files\\NoPorts";
#else
		private readonly string _directory = AppContext.BaseDirectory;
#endif

		public Service(ILogger<Service> logger)
		{
			_logger = logger;
		}

		protected override async Task ExecuteAsync(CancellationToken ct)
		{
			Binary service;
			do
			{
				service = new(ChildProcess.StartInfo(_directory, Environment.GetCommandLineArgs().Skip(1)), _logger);
				try
				{
					await service.Run(ct);
				}
				catch (Exception ex) when (ex is not OperationCanceledException)
				{
					_logger.LogError($"Process {ServiceConfig.Binary} {ServiceConfig.Subcommand} exited with error: {ex.Message}");
					await service.Stop();
					// Terminates this process and returns an exit code to the operating system.
					// This is required to avoid the 'BackgroundServiceExceptionBehavior', which
					// performs one of two scenarios:
					// 1. When set to "Ignore": will do nothing at all, errors cause zombie services.
					// 2. When set to "StopHost": will cleanly stop the host, and log errors.
					//
					// In order for the Windows Service Management system to leverage configured
					// recovery options, we need to terminate the process with a non-zero exit code.
					Environment.Exit(1);
				}
			} while (!ct.IsCancellationRequested);
		}
	}
}
