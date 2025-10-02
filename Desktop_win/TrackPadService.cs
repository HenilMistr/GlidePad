using System;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Win32;
using InTheHand.Net.Bluetooth; // Install-Package 32feet.NET
using InTheHand.Net.Sockets;

public partial class TrackPadService : Form
{
    private BluetoothListener listener;
    private BluetoothClient client;
    private NotifyIcon trayIcon;

    public TrackPadService()
    {
        InitializeComponent();
        SetupTrayIcon();
        StartBluetoothServer();
        SendProfileToConnectedDevice(); // When connected
    }

    private void SetupTrayIcon()
    {
        trayIcon = new NotifyIcon
        {
            Icon = Properties.Resources.AppIcon,
            Visible = true,
            Text = "TrackPad Host - Waiting for phone..."
        };
    }

    private async void StartBluetoothServer()
    {
        var localRadio = BluetoothRadio.PrimaryRadio;
        localRadio.Mode = RadioMode.Connectable;

        listener = new BluetoothListener(BluetoothService.SerialPort);
        listener.Start();

        trayIcon.Text = "TrackPad Host - Ready for phone...";

        while (true)
        {
            client = await listener.AcceptBluetoothClientAsync();
            trayIcon.Text = "TrackPad Host - Phone CONNECTED!";

            // Send OS profile immediately
            await SendProfileAsync();

            // Handle incoming commands (in background)
            _ = Task.Run(HandleIncomingCommands);
        }
    }

    private async Task SendProfileAsync()
    {
        var profile = new
        {
            os = "windows",
            naturalScroll = IsNaturalScrollEnabled(),
            tapToClick = IsTapToClickEnabled(),
            hasPrecisionTouchpad = HasPrecisionTouchpad()
        };

        string json = Newtonsoft.Json.JsonConvert.SerializeObject(new { profile });
        byte[] buffer = System.Text.Encoding.UTF8.GetBytes(json + "\n");

        await client.GetStream().WriteAsync(buffer, 0, buffer.Length);
    }

    private bool IsNaturalScrollEnabled()
    {
        using (var key = Registry.CurrentUser.OpenSubKey(
            @"Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"))
        {
            object val = key?.GetValue("FlipFlopWheel");
            return val is int i && i == 1;
        }
    }

    private bool IsTapToClickEnabled()
    {
        using (var key = Registry.CurrentUser.OpenSubKey(
            @"Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"))
        {
            object val = key?.GetValue("EnableMouseClickLock");
            return val is int i && i == 1;
        }
    }

    private bool HasPrecisionTouchpad()
    {
        // Simplified — real version uses Windows.Devices.Input
        return true; // Assume yes for MVP
    }

    private async Task HandleIncomingCommands()
    {
        var stream = client.GetStream();
        var reader = new System.IO.StreamReader(stream);

        while (client.Connected)
        {
            try
            {
                string line = await reader.ReadLineAsync();
                if (string.IsNullOrEmpty(line)) continue;

                dynamic cmd = Newtonsoft.Json.JsonConvert.DeserializeObject(line);

                switch (cmd.cmd.ToString())
                {
                    case "move":
                        MoveCursor((int)cmd.dx, (int)cmd.dy);
                        break;
                    case "tap":
                        DoClick((int)cmd.fingers);
                        break;
                    case "scroll":
                        DoScroll((int)cmd.dy);
                        break;
                }
            }
            catch { break; }
        }
    }

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    static extern void mouse_event(int dwFlags, int dx, int dy, int dwData, int dwExtraInfo);

    const int MOUSEEVENTF_MOVE = 0x0001;
    const int MOUSEEVENTF_LEFTDOWN = 0x0002;
    const int MOUSEEVENTF_LEFTUP = 0x0004;
    const int MOUSEEVENTF_WHEEL = 0x0800;

    void MoveCursor(int dx, int dy)
    {
        mouse_event(MOUSEEVENTF_MOVE, dx, dy, 0, 0);
    }

    void DoClick(int fingers)
    {
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);
        mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);
    }

    void DoScroll(int delta)
    {
        mouse_event(MOUSEEVENTF_WHEEL, 0, 0, -delta * 40, 0); // Invert if needed
    }
}