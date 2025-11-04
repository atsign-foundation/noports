// The Windows BackgroundService interface
// This starts up the appropriate dart binary

namespace WindowsBinaryService
{
	public static class ServiceConfig
	{
#if SRVD
        public const string Binary = "srvd.exe";
        public const string Name = "srvd";
        public const string DisplayName = "NoPorts Relay";
#elif SSHNPD
        public const string Binary = "sshnpd.exe";
        public const string Name = "sshnpd";
        public const string DisplayName = "NoPorts Daemon";
#else
		public const string Binary = "sshnpd.exe";
		public const string Name = "sshnpd";
		public const string DisplayName = "NoPorts Daemon";
#endif
	}

	public class Service : BackgroundService
	{

		private readonly ILogger<Service> _logger;
#if DEBUG
		private const string basedir = "C:\\Program Files\\NoPorts";
		private readonly string _servicePath = Path.Join(basedir, ServiceConfig.Binary);
#else
		private readonly string _servicePath = Path.Join(AppContext.BaseDirectory, ServiceConfig.Binary);
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
				service = new(_servicePath, _logger);
				try
				{
					await service.Run(ct);
				}
				catch (Exception ex) when (ex is not OperationCanceledException)
				{
					_logger.LogError($"Process {ServiceConfig.Binary} exited with error: {ex.Message}");
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
