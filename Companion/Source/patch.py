import re

with open(r'D:\Tools\Code\Offhand\Companion\Source\Program.cs', 'r', encoding='utf-8') as f:
    code = f.read()

# 1. Add Config variables and ComboBox
declarations = '''        private NumericUpDown numDelaySpan;
        private Label lblDelay;
        private ComboBox cmbHotkey;
        private Label lblHotkey;

        private static Dictionary<string, string> appSettings = new Dictionary<string, string>();
        private static string configPath = "OffhandConfig.ini";

        private void LoadConfig()
        {
            if (File.Exists(configPath))
            {
                foreach (var line in File.ReadAllLines(configPath))
                {
                    var parts = line.Split('=');
                    if (parts.Length == 2) appSettings[parts[0].Trim()] = parts[1].Trim();
                }
            }
        }

        private void SaveConfig()
        {
            var lines = new System.Collections.Generic.List<string>();
            foreach(var kv in appSettings) lines.Add(kv.Key + "=" + kv.Value);
            File.WriteAllLines(configPath, lines);
        }
'''
code = re.sub(r'private NumericUpDown numDelaySpan;\s*private Label lblDelay;', declarations, code)

# 2. Call LoadConfig() in constructor
code = re.sub(r'(public CompanionForm\(\)\s*\{\s*)', r'\1LoadConfig();\n            ', code)

# 3. Increase Window and Config Panel Height further for Hotkey dropdown
code = re.sub(r'this\.Size = new Size\(\d+, \d+\);', 'this.Size = new Size(524, 700);', code)
code = re.sub(r'CreateCardPanel\(16, 230, 490, 90, "Configuration"\);', 'CreateCardPanel(16, 230, 490, 126, "Configuration");', code)

# Shift lower elements by 36
code = re.sub(r'btnSpanNow = CreateButton\("Span WoW Window Now", 16, 332,', 'btnSpanNow = CreateButton("Span WoW Window Now", 16, 368,', code)
code = re.sub(r'btnToggleWatch = CreateButton\("Pause Monitoring", 262, 332,', 'btnToggleWatch = CreateButton("Pause Monitoring", 262, 368,', code)
code = re.sub(r'Panel logPanel = CreateCardPanel\(16, 380, 490, 200, "Activity Log"\);', 'Panel logPanel = CreateCardPanel(16, 416, 490, 200, "Activity Log");', code)
code = re.sub(r'Button btnMinimize = CreateButton\("Minimize to Tray", 16, 592,', 'Button btnMinimize = CreateButton("Minimize to Tray", 16, 628,', code)
code = re.sub(r'Button btnExit = CreateButton\("Exit Companion", 356, 592,', 'Button btnExit = CreateButton("Exit Companion", 356, 628,', code)


# 4. Inject Hotkey UI and load settings
ui_injection = '''            configPanel.Controls.Add(numDelaySpan);

            lblHotkey = new Label { Text = "Global Hotkey:", Location = new Point(10, 84), Size = new Size(130, 22), ForeColor = cText, BackColor = Color.Transparent };
            configPanel.Controls.Add(lblHotkey);
            cmbHotkey = new ComboBox { Location = new Point(140, 82), Size = new Size(160, 22), DropDownStyle = ComboBoxStyle.DropDownList, BackColor = cCard, ForeColor = cText };
            cmbHotkey.Items.AddRange(new object[] { "Ctrl+Alt+S", "Ctrl+Shift+S", "Alt+S", "F10", "F11", "F12" });
            cmbHotkey.SelectedIndex = 0;
            if (appSettings.ContainsKey("Hotkey") && cmbHotkey.Items.Contains(appSettings["Hotkey"])) cmbHotkey.SelectedItem = appSettings["Hotkey"];
            
            cmbHotkey.SelectedIndexChanged += (s, e) => { 
                appSettings["Hotkey"] = cmbHotkey.SelectedItem.ToString(); 
                SaveConfig(); 
                UpdateHotkey();
            };
            configPanel.Controls.Add(cmbHotkey);

            if (appSettings.ContainsKey("AutoSpan")) chkAutoSpan.Checked = appSettings["AutoSpan"] == "True";
            if (appSettings.ContainsKey("DelaySpan")) { if (decimal.TryParse(appSettings["DelaySpan"], out decimal d)) numDelaySpan.Value = d; }

            chkAutoSpan.CheckedChanged += (s, e) => { appSettings["AutoSpan"] = chkAutoSpan.Checked.ToString(); SaveConfig(); };
            numDelaySpan.ValueChanged += (s, e) => { appSettings["DelaySpan"] = numDelaySpan.Value.ToString(); SaveConfig(); };
'''

code = re.sub(r'configPanel\.Controls\.Add\(numDelaySpan\);', ui_injection, code)

# 5. Add UpdateHotkey method
hotkey_logic = '''        private void UpdateHotkey()
        {
            NativeMethods.UnregisterHotKey(this.Handle, 1);
            int modifier = 0;
            int key = 0;
            string sel = cmbHotkey.SelectedItem.ToString();
            
            if (sel == "Ctrl+Alt+S") { modifier = 0x0002 | 0x0001; key = (int)Keys.S; } // Alt is 1, Ctrl is 2
            else if (sel == "Ctrl+Shift+S") { modifier = 0x0002 | 0x0004; key = (int)Keys.S; } // Ctrl is 2, Shift is 4
            else if (sel == "Alt+S") { modifier = 0x0001; key = (int)Keys.S; }
            else if (sel == "F10") { modifier = 0; key = (int)Keys.F10; }
            else if (sel == "F11") { modifier = 0; key = (int)Keys.F11; }
            else if (sel == "F12") { modifier = 0; key = (int)Keys.F12; }
            
            NativeMethods.RegisterHotKey(this.Handle, 1, modifier, key);
            AddLog("Global Hotkey Registered: " + sel + " to Span Now.");
        }
'''
code = re.sub(r'public CompanionForm\(\)', hotkey_logic + r'\n        public CompanionForm()', code)

# 6. Replace the old hardcoded hotkey register
code = re.sub(r'NativeMethods\.RegisterHotKey\(this\.Handle, 1, 0x0002 \| 0x0004, \(int\)Keys\.S\);\s*// Ctrl\+Alt\+S\s*AddLog\("Global Hotkey Registered: Ctrl\+Alt\+S to Span Now\."\);', 'UpdateHotkey();', code)

with open(r'D:\Tools\Code\Offhand\Companion\Source\Program.cs', 'w', encoding='utf-8') as f:
    f.write(code)
