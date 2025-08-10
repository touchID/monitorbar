//------------------------------------------------------------------------------
// This file is part of Monitor Bar. Copyright (c) tidiemme.
// You should have received a copy of the MIT License along with Monitor Bar.
// If not see <https://opensource.org/licenses/MIT>.
//------------------------------------------------------------------------------

import Foundation
import SwiftUI
import CoreLocation

class MenuBar {
    var statusItem: NSStatusItem!
    var menu : NSMenu!
    
    private var settings = MenuBarSettings()
    
    private var monitor = Monitor()
    
    private var ip : MeterIp
    private var network : MeterNetwork
    private var cpu : MeterCpu
    private var mem : MeterMemory
    private var disk : MeterDisk
    private var battery : MeterBattery
    
    static var charPercentage = NSMutableAttributedString(string: String(format: "%%")
                                                  ,attributes: StringAttribute.small)
    static var charPercentageWidth = 0.0
    
    init(){
        settings.initialise()
        MenuBar.charPercentageWidth = Double(MenuBar.charPercentage.size().width)
        ip = MeterIp()
        network = MeterNetwork()
        cpu = MeterCpu()
        mem = MeterMemory()
        disk = MeterDisk()
        battery = MeterBattery()
    }
    
    func reset() {
        ip = MeterIp()
        network = MeterNetwork()
        cpu = MeterCpu()
        mem = MeterMemory()
        disk = MeterDisk()
        battery = MeterBattery()
    }
    
    func initialise() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        menu = NSMenu()
        //let menuSettings = NSMenuItem()
        //menuSettings.title = "Settings"
        //menuSettings.submenu = NSMenu(title: "Settings")
        //menuSettings.submenu?.items = [NSMenuItem(title: "Compact"
        //                               ,action: #selector(AppDelegate.appMonitorClicked(_:)), keyEquivalent: "s")]
        //menu.addItem(menuSettings)
        menu.addItem(NSMenuItem(title: "无"//Compact
                    ,action: #selector(AppDelegate.zero(_:)), keyEquivalent: "0"))
        menu.addItem(NSMenuItem(title: "图标"//Compact
                    ,action: #selector(AppDelegate.compact(_:)), keyEquivalent: "t"))
        menu.addItem(NSMenuItem(title: "数字"//Normal
                    ,action: #selector(AppDelegate.normal(_:)), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "详细"//Extra
                    ,action: #selector(AppDelegate.extra(_:)), keyEquivalent: "x"))
        
        menu.addItem(NSMenuItem(title: "Activity Monitor任务管理器"
                    ,action: #selector(AppDelegate.appMonitorClicked(_:)), keyEquivalent: "a"))
        
        menu.addItem(NSMenuItem(title: "Quit"
                    ,action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
        
        update()
    }
    
    func update() {
        ip.update(monitor)
        network.update(monitor)
        cpu.update(monitor)
        mem.update(monitor)
        disk.update(monitor)
        battery.update(monitor)
        
        let mbWidth = ip.containerWidth
                    + network.containerWidth
                    + cpu.containerWidth
                    + mem.containerWidth
                    + disk.containerWidth
                    + battery.containerWidth
                    - (MenuBarSettings.arrowWidth * 5.0)
                    + (MenuBarSettings.itemsSpacing * 5.0)
        
        let mbHeight = MenuBarSettings.menubarHeight
        
        let image = NSImage( size: NSSize( width: mbWidth, height: mbHeight))
        image.lockFocus()
        
        var pos = 0.0
        ip.draw(pos, MenuBarSettings.themes[MenuBarSettings.theme][0])
        pos += ip.containerWidth - MenuBarSettings.arrowWidth + MenuBarSettings.itemsSpacing
        network.draw(pos, MenuBarSettings.themes[MenuBarSettings.theme][1])
        pos += network.containerWidth - MenuBarSettings.arrowWidth + MenuBarSettings.itemsSpacing
        cpu.draw(pos, MenuBarSettings.themes[MenuBarSettings.theme][2])
        pos += cpu.containerWidth - MenuBarSettings.arrowWidth + MenuBarSettings.itemsSpacing
        mem.draw(pos, MenuBarSettings.themes[MenuBarSettings.theme][3])
        pos += mem.containerWidth - MenuBarSettings.arrowWidth + MenuBarSettings.itemsSpacing
        disk.draw(pos, MenuBarSettings.themes[MenuBarSettings.theme][4])
        pos += disk.containerWidth - MenuBarSettings.arrowWidth + MenuBarSettings.itemsSpacing
        battery.draw(pos, MenuBarSettings.themes[MenuBarSettings.theme][5])
        
        image.unlockFocus()
        // 回到主线程更新UI
        DispatchQueue.main.async {
            // 这里可以添加UI更新代码（如果有的话）
            // 找到处理模式的代码部分，添加对模式0的处理
            if MenuBarSettings.mode == 0 {
                // 无图标模式的具体实现
                self.statusItem?.button?.image = nil
//                self.statusItem?.button?.title = ""
            } else {
                self.statusItem?.button?.image = image
            }
            NetworkServiceUtil.shared.executeNetworkCommand(arguments: ["-listnetworkserviceorder"]) { [weak self] output in
                if let self = self, let output = output {
                    let services = NetworkServiceUtil.shared.parseNetworkServices(from: output)
                    DispatchQueue.main.async {
                        self.statusItem?.button?.title = services.first ?? ""
                    }
                }
            }
        }
    }
}
