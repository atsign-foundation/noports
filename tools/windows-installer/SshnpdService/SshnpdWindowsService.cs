namespace SshnpdService
{
    public class SshnpdWindowsService : BackgroundService
    {
        private readonly ILogger<SshnpdWindowsService> _logger;
        private readonly Sshnpd _sshnpdService;
        private readonly IHostApplicationLifetime _lifetime;

        public SshnpdWindowsService(Sshnpd sshnpdService, ILogger<SshnpdWindowsService> logger, IHostApplicationLifetime lifetime)
        {
            _sshnpdService = sshnpdService;
            _logger = logger;
            _lifetime = lifetime;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    while (!stoppingToken.IsCancellationRequested)
                    {
                        await _sshnpdService.Run(stoppingToken);
                        _logger.LogInformation("Sshnpd service is restarting...");
                    }
                }
                catch (OperationCanceledException)
                {
                    // _sshnpdService.Close();
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

            }
            _sshnpdService.Close();
        }
    }
}
