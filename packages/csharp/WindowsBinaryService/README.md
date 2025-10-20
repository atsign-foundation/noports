
## Build Commands

### Prerequisites
- .NET SDK installed
- Visual Studio or Visual Studio Code (optional)


### Publish

```bash
# Publish self-contained executable

#define constants is a feature flag, this is what decides what binary to build
dotnet publish --configuration Release -p:DefineConstants="SSHNPD"

```

