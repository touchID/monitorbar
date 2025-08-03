//------------------------------------------------------------------------------
// This file is part of Monitor Bar. Copyright (c) tidiemme.
// You should have received a copy of the MIT License along with Monitor Bar.
// If not see <https://opensource.org/licenses/MIT>.
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// 应用程序入口和主控制器
//------------------------------------------------------------------------------
import SwiftUI
import AppKit

// 应用程序主入口
@main
struct mbApp: App {
    // 使用AppDelegateAdaptor将AppDelegate与SwiftUI应用关联
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// 应用程序委托，处理生命周期和主要业务逻辑
class AppDelegate: NSObject, NSApplicationDelegate {
    // 静态常量：更新间隔（秒），控制菜单栏数据刷新频率
    static let updateInterval : Double = 5.0
    // 静态实例：菜单栏管理器，负责显示和更新菜单栏内容
    static let menuBar = MenuBar()
    
    // 定时器：用于定期触发数据更新
    private var timer: RepeatingTimer!
    
    // 应用程序启动完成时调用
    func `applicationDidFinishLaunching`(_ notification: Notification) {
        // 初始化菜单栏
        AppDelegate.menuBar.initialise()
        
        // 创建并启动定时器，每隔updateInterval秒触发一次fireTimer方法
        timer = RepeatingTimer(AppDelegate.updateInterval)
        timer.eventHandler = fireTimer
        timer.resume()
        
        // 注册系统唤醒通知观察者
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(self.onWakeUp(notification:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        // 注册系统睡眠通知观察者
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(self.onSleep(notification:)),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        handleWiFiAction(nil)
    }
    
    // 构建菜单栏右键菜单
    func buildMenu() {
        let menu = NSMenu()
        // 添加退出菜单项
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        AppDelegate.menuBar.statusItem?.button?.menu = menu
    }
    
    // 定时器触发时调用，更新菜单栏数据
    @objc func fireTimer() {
        // 在后台队列执行数据收集
        DispatchQueue.global(qos: .utility).async {
            // 收集所有数据
            AppDelegate.menuBar.update()
        }
    }
    
    @objc func appMonitorClicked(_ sender: Any) {
        let conf = NSWorkspace.OpenConfiguration()
        conf.hidesOthers = false // if true, hide other apps when open
        conf.hides = false // if true, open app but doesn't show window
        conf.activates = false // if true, open app and move front most
        // conf.arguments, you can past arguments. you might use to exec command line tool
        // conf.environment, you can set enviromentl variables.
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
                                          ,configuration: conf)
    }
    
    @objc func handleCurrentOrderAction(_ sender: NSMenuItem?) {
        executeNetworkCommand(arguments: ["-listnetworkserviceorder"]) { output in
            if let output = output { print(output) }
        }
    }

    @objc func handleEthernetAction(_ sender: NSMenuItem?) {
        executeNetworkCommand(arguments: ["-switchtolocation", "Automatic"]) { output in
            guard let output = output else { return }
        }
    }

    @objc func handleWiFiAction(_ sender: NSMenuItem?) {  // 将参数改为可选类型
        // 使用工具类设置WiFi为首要网络服务
        NetworkServiceUtil.shared.setWifiAsPrimary()
    }
    
    private func executeNetworkCommand(arguments: [String], completion: ((String?) -> Void)? = nil) {
//        DispatchQueue.global(qos: .utility).async {
            let task = Process()
            task.launchPath = "/usr/sbin/networksetup"
            task.arguments = arguments
            let pipe = Pipe()
            task.standardOutput = pipe
            task.launch()
            task.waitUntilExit()
            if let completion = completion {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                completion(String(data: data, encoding: .utf8))
            }
//        }
    }

    private func shell(launchPath: String, arguments: [String]) -> String
    {
        let task = Process()
        task.launchPath = launchPath
        task.arguments = arguments

        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output: String = String(data: data, encoding: String.Encoding.utf8)!

        return output
    }

    
    @objc func zero(_ sender: NSMenuItem?) {
        AppDelegate.setMode(0)
    }
    
    @objc func compact(_ sender: Any) {
        AppDelegate.setMode(1)
    }
    
    // 切换到普通模式（显示标准信息）
    @objc func normal(_ sender: Any) {
        AppDelegate.setMode(2)
    }
    
    // 切换到扩展模式（显示最多信息）
    @objc func extra(_ sender: Any) {
        AppDelegate.setMode(3)
    }
    
    // 设置显示模式并保存到用户偏好设置
    static func setMode(_ mode : Int) {
        MenuBarSettings.mode = mode
        UserDefaults.standard.set(mode, forKey: "Mode")
        AppDelegate.menuBar.reset()
        AppDelegate.menuBar.update()
    }
    
    // 系统进入睡眠状态时暂停定时器
    @objc private func onSleep(notification: NSNotification) {
        timer.suspend()
    }
    
    // 系统唤醒时恢复定时器
    @objc private func onWakeUp(notification: NSNotification) {
        timer.resume()
    }
}
