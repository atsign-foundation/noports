using System.Diagnostics;
using System.IO;

namespace NoPortsInstaller
{
    class ActivateController
    {
        private readonly IController _controller = App.ControllerInstance;
        public Process AtActivate { get; set; }
        ActivateController()
        {
            AtActivate = new Process();
            AtActivate.StartInfo.FileName = Path.Combine(_controller.InstallDirectory, "AtActivate.exe");
            AtActivate.StartInfo.Arguments = $"interactive -a {_controller.DeviceAtsign}";
            AtActivate.StartInfo.UseShellExecute = false;
            AtActivate.StartInfo.RedirectStandardOutput = true;
            AtActivate.StartInfo.RedirectStandardInput = true;
            AtActivate.StartInfo.RedirectStandardError = true;
            AtActivate.StartInfo.CreateNoWindow = true;
        }

        private async Task<List<string>> RunCommand(string command)
        {
            AtActivate.StandardInput.Write(command);
            AtActivate.StandardInput.Flush();
            List<string> response = [];
            string? line = await AtActivate.StandardOutput.ReadLineAsync();
            while (line != null)
            {
                response.Add(line);
            }
            return response;
        }

        public async Task Approve(string enrollmentId)
        {

        }

        public async Task GenerateOTP()
        {

        }

        public async Task<string> ListEnrollments()
        {
            var args = "list";
            var response = await RunCommand(args);
            foreach (var line in response)
            {
                if (line.Contains("pending"))
                {
                    var segs = line.Trim().Split(" ").ToList();
                    segs.RemoveAll(x => x == "");
                    _controller.DeviceName = segs[3];
                    return segs[0];
                }
            }
            return "";
        }
    }
}
