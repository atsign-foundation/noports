cask "noports" do
  arch arm: "arm64", intel: "x64"
  os macos: "macos", linux: "linux"
  version 'v5.13.0'

  macos_arm64_sha = '83ca40f17c7bfc0d873f810e41b1cd8ab9fc290ac38a3ef38ecd11f396742df6'
  macos_x64_sha = '69500b83cce4fa460569dae0e2e5a1ad225d2454a421c823b22379acbcdae223'
  linux_arm64_sha = '896f1d23d96d8de71853f6e2b24e33c4e8c4837bab0c9560932abc5cc7741f7a'
  linux_x64_sha = '8598e0e07cc82bb22982139477e3310080eb7634d738cd60453c676ea97f66fd'

  # N.B. Be careful about the formatting in the above lines.
  # They are automatically updated by: .github/workflows/multibuild.yaml

  on_macos do
    on_arm do
      sha256 macos_arm64_sha
    end
    on_intel do
      sha256 macos_x64_sha
    end
    url "https://github.com/atsign-foundation/noports/releases/download/#{version}/sshnp-#{os}-#{arch}.zip"
  end
  on_linux do
    on_arm do
      sha256 linux_arm64_sha
    end
    on_intel do
      sha256 linux_x64_sha
    end
    url "https://github.com/atsign-foundation/noports/releases/download/#{version}/sshnp-#{os}-#{arch}.tgz"
  end
 
  name "noports"
  desc "Make your devices invisible (https://noports.com)"
  homepage "https://noports.com"

  depends_on formula: "ca-certificates"

  binary "sshnp/at_activate"
  binary "sshnp/srv"
  binary "sshnp/npt"
  binary "sshnp/sshnp"
  binary "sshnp/sshnpd"
  binary "sshnp/srvd"
  binary "sshnp/npp_atserver"
  binary "sshnp/npp_file"
  binary "sshnp/npa_file"

  on_macos do
    service "sshnp/launchd/com.atsign.sshnpd.plist"
    artifact "sshnp/config/sshnpd.yaml",
      target: "~/Library/Application Support/Noports/sshnpd.yaml"
  end

  on_linux do
    service "sshnp/systemd/sshnpd.service"
    artifact "sshnp/config/sshnpd.yaml",
      target: "/etc/noports/sshnpd.yaml"
  end


  zap do
    trash [
      "~/.atsign/sshnp", # Trash runtime cache when zapped (uninstall + extras)
    ]
  end

  on_linux do
    caveats <<~EOS
      NoPorts Daemon installed to: /etc/systemd/system/sshnp.service
      To edit the configuration:

      sudo nano /etc/noports/sshnpd.yaml

      Once configured, the following commands can be used to manage the service.
      Enable/disable automatic startup:

      systemctl enable sshnpd
      systemctl disable sshnpd

      Immediately start/stop/restart the service:

      systemctl start sshnpd
      systemctl stop sshnpd
      systemctl restart sshnpd

      View status/logs:

      systemctl status sshnpd
      journalctl -u sshnpd
    EOS
  end
  on_macos do
    caveats <<~EOS
      NoPorts Daemon installed to: ~/Library/Services/com.atsign.sshnpd.plist
      To edit the configuration:

      textedit "~/Library/Application Support/NoPorts/sshnpd.yaml"

      The service can be enabled or disabled from System Settings under the "Login Items" menu.
    EOS
  end
end
