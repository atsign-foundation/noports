using System.Diagnostics;
using WindowsBinaryService;

var builder = Host.CreateApplicationBuilder(args);

// Register as a Windows Service
builder.Services.AddWindowsService(options =>
{
    options.ServiceName = ServiceConfig.Name;
    options.DisplayName = ServiceConfig.DisplayName;
});

// Configure logging to use EventLog (and Console for development)
builder.Logging.ClearProviders();
builder.Logging.AddConsole(); // optional: keep console logs when running interactively
#pragma warning disable CA1416 // Validate platform compatibility
if (!EventLog.SourceExists("NoPorts"))
{
    EventLog.CreateEventSource("NoPorts", ServiceConfig.Name);
}
// The source can exist without the log existing.....?
if (!EventLog.Exists(ServiceConfig.Name))
{
    EventLog.CreateEventSource("NoPorts", ServiceConfig.Name);
}
builder.Logging.AddEventLog(eventLogSettings =>
{
    eventLogSettings.LogName = ServiceConfig.Name;
    eventLogSettings.SourceName = "NoPorts";
    eventLogSettings.Filter = (category, logLevel) => logLevel >= LogLevel.Information;
});
#pragma warning restore CA1416 // Validate platform compatibility

// Register the hosted/background service
builder.Services.AddHostedService<Service>();

var host = builder.Build();
host.Run();
