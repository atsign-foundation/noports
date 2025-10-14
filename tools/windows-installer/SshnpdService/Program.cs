using Microsoft.Extensions.Logging.Configuration;
using Microsoft.Extensions.Logging.EventLog;
using SshnpdService;

var builder = Host.CreateApplicationBuilder(args);
builder.Services.AddWindowsService(options =>
{
    options.ServiceName = "sshnpd";
});

LoggerProviderOptions.RegisterProviderOptions<
    EventLogSettings, EventLogLoggerProvider>(services: builder.Services);

builder.Services.AddLogging(loggingBuilder => loggingBuilder
    .AddEventLog()
    .AddFilter<EventLogLoggerProvider>("Microsoft", LogLevel.Warning)
    .AddFilter<EventLogLoggerProvider>("System", LogLevel.Warning)
    .AddFilter<EventLogLoggerProvider>("NoPorts", LogLevel.Information));

builder.Services.AddSingleton<Sshnpd>();
builder.Services.AddHostedService<SshnpdWindowsService>();


var host = builder.Build();
host.Run();
