// Entrypoint for the project
// Registers the service and Event logger

#pragma warning disable CA1416 // Ignore platform specific calls, this is windows only

using WindowsBinaryService;

// Create a builder for the service application
var builder = Host.CreateApplicationBuilder(new HostApplicationBuilderSettings
{
	ApplicationName = ServiceConfig.Name,
});

// Register a service name with the host
builder.Services.AddWindowsService(options =>
{
	options.ServiceName = ServiceConfig.Name;
});

// Register the Windows Service Interface
builder.Services.AddHostedService<Service>();

// Run
builder.Build().Run();
