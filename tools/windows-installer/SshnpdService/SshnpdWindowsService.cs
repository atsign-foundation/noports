namespace SshnpdService
{
    /// <summary>
    /// Represents a Windows service for the Sshnpd application.
    /// </summary>
    public class SshnpdWindowsService : BackgroundService
    {
        private readonly ILogger<SshnpdWindowsService> _logger;
        private readonly Sshnpd _sshnpdService;

        /// <summary>
        /// Initializes a new instance of the <see cref="SshnpdWindowsService"/> class.
        /// </summary>
        /// <param name="sshnpdService">The Sshnpd service instance.</param>
        /// <param name="logger">The logger instance.</param>
        public SshnpdWindowsService(Sshnpd sshnpdService, ILogger<SshnpdWindowsService> logger)
        {
            _sshnpdService = sshnpdService;
            _logger = logger;
        }

        /// <summary>
        /// Executes the Sshnpd service asynchronously.
        /// </summary>
        /// <param name="stoppingToken">The cancellation token to stop the service.</param>
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
