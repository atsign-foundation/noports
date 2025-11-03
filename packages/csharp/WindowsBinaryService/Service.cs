namespace WindowsBinaryService
{
    public static class ServiceConfig
    {
#if SRVD
        public const string Binary = "srvd.exe";
        public const string DisplayName = "NoPorts Relay";
        public const string Name = "NoPortsRelay";
#elif SSHNPD
        public const string Binary = "sshnpd.exe";
        public const string DisplayName = "NoPorts Daemon";
        public const string Name = "NoPortsDaemon";
#else
        public const string Binary = "sshnpd.exe";
        public const string DisplayName = "NoPorts Daemon";
        public const string Name = "NoPortsDaemon";
#endif
    }


    public class Service : BackgroundService
    {

        private readonly ILogger<Service> _logger;
        private readonly string _servicePath = Path.Join(AppContext.BaseDirectory, ServiceConfig.Binary);

        public Service(ILogger<Service> logger)
        {
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            Binary service = new(_servicePath, _logger);
            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    while (!stoppingToken.IsCancellationRequested)
                    {
                        await service.RunBinary(stoppingToken);
                        await service.WaitForExit();
                    }
                }
                catch (OperationCanceledException)
                {
                    service.Stop();
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "{Message}", ex.Message);

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
                service = new(_servicePath, _logger);
            }
            service.Stop();
        }
    }
}
