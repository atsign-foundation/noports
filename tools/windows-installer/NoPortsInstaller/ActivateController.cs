using System.Diagnostics;
using System.IO;

namespace NoPortsInstaller
{
    class ActivateController
    {
        private readonly IController _controller = App.ControllerInstance;

        ActivateController()
        {
            AtActivate = new Process();
            AtActivate.StartInfo.FileName = Path.Combine(
                _controller.InstallDirectory,
                "AtActivate.exe"
            );
            AtActivate.StartInfo.Arguments = $"interactive -a {_controller.DeviceAtsign}";
            AtActivate.StartInfo.UseShellExecute = false;
            AtActivate.StartInfo.RedirectStandardOutput = true;
            AtActivate.StartInfo.RedirectStandardInput = true;
            AtActivate.StartInfo.RedirectStandardError = true;
            AtActivate.StartInfo.CreateNoWindow = true;
        }

        private async Task<List<string>> RunCommand(string args)
        {
            List<string> stdout = [];
            List<string> stderr = [];
            int exitCode;
            using (var process = new Process())
            {
                var startInfo = process.StartInfo;

                startInfo.FileName = Path.Combine(_controller.InstallDirectory, "AtActivate.exe");
                startInfo.UseShellExecute = false;
                startInfo.RedirectStandardOutput = true;
                startInfo.RedirectStandardInput = true;
                startInfo.RedirectStandardError = true;
                startInfo.CreateNoWindow = true;
                startInfo.Arguments = args;

                process.Start();

                process.StandardInput.Write(command);
                process.StandardInput.Flush();

                while (!process.StandardOutput.EndOfStream)
                {
                    string line = process.StandardOutput.ReadLine();
                    stdout.Add(line);
                }

                while (!process.StandardError.EndOfStream)
                {
                    string line = process.StandardError.ReadLine();
                    stderr.Add(line);
                }

                process.WaitForExit();

                exitCode = process.ExitCode;
            }

            if (exitCode != 0)
            {
                throw new System.Exception(String.Join("\n", stderr));
            }

            return stdout;
        }

        public async Task Approve(string enrollmentId)
        {
            var args = $"deny -a {_controller.DeviceAtsign} -i {enrollmentId}";
            await RunCommand(args);
        }

        public async Task Deny(string enrollmentId)
        {
            var args = $"deny -a {_controller.DeviceAtsign} -i {enrollmentId}";
            await RunCommand(args);
        }

        public async Task<string> GenerateOTP()
        {
            var args = $"otp -a {_controller.DeviceAtsign}";
            var response = await RunCommand(args);

            return response[0];
        }

        private string AppName = "noports_win";
        private List<string> Namespaces = ["{sshnp: rw, sshrvd: rw}", "{sshrvd: rw, sshnp: rw}"];

        public async Task<bool> Enroll(string otp)
        {
            var args =
                $"enroll -a {_controller.DeviceAtsign} -s {otp} -p {AppName} -d {_controller.DeviceName} -n {Namespaces[0]} -k {_controller.AtsignKeysDirectory}";
            var response = await RunCommand(args);

            if (response.Last.Contains(["Success"]))
            {
                return true;
            }

            return false;
        }

        public async Task<List<EnrollmentRecord>> ListEnrollments()
        {
            var args = "list -s pending";
            var response = await RunCommand(args);

            List<EnrollmentRecord> lines = [];
            for (int i = 2; i < response.Count; i++)
            {
                var parts = line.Trim().Split(" ").ToList();
                parts.RemoveAll(x => x == "");
                if (x[2] != AppName || !Namespaces.Contains(x[4]))
                {
                    continue;
                }

                EnrollmentRecord record = EnrollmentRecord(x[0], x[3]);
                lines.Add(record);
            }

            return lines;
        }
    }

    class EnrollmentRecord
    {
        string Id { get; set; }
        string DeviceName { get; set; }

        EnrollmentRecord(string Id, String DeviceName)
        {
            this.Id = Id;
            this.DeviceName = DeviceName;
        }
    }
}
