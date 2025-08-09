//
//  NetworkServiceUtil.swift
//  mb
//
//  Created by lu on 2025/8/3.
//

import Foundation

/// 网络服务顺序工具类
/// 提供设置首要网络接口的功能
class NetworkServiceUtil {
    /// 单例实例
    static let shared = NetworkServiceUtil()
    
    /// 解析networksetup -listnetworkserviceorder输出的网络服务列表
    func parseNetworkServices(from output: String) -> [String] {
        var services: [String]
        do {
            // 修改正则表达式以匹配多行格式的网络服务输出
            let regex = try NSRegularExpression(pattern: #"\(\d+\)\s+([^\n]+)\s*\n\s*\(Hardware Port: (.+?), Device: (.+?)\)"#,
                                               options: .caseInsensitive)
            let matches = regex.matches(in: output, options: [], range: NSRange(location: 0, length: output.utf16.count))

            services = matches.compactMap { match in
                if let range = Range(match.range(at: 1), in: output) {
                    // 去除服务名称两端的空白字符
                    return String(output[range]).trimmingCharacters(in: .whitespaces)
                }
                return nil
            }

            // 添加调试信息
            if services.isEmpty {
                print("未找到网络服务，请检查以下输出格式:")
                print(output)
            } else {
                print("成功解析到\(services.count)个网络服务")
            }
        } catch {
            print("解析网络服务列表失败: \(error)")
            services = []
        }
        return services
    }
    
    /// 重新排序网络服务列表，将WiFi移到首位
    func reorderServicesWithEthernetFirst(services: [String]) -> [String] {
        var reordered = services.filter { $0.lowercased().contains("ethernet") || $0.lowercased().contains("以太网") }
        reordered.append(contentsOf: services.filter { !$0.lowercased().contains("ethernet") && !$0.lowercased().contains("以太网") })
        return reordered
    }
    /// 重新排序网络服务列表，将WiFi移到首位
    func reorderServicesWithWifiFirst(services: [String]) -> [String] {
        var reordered = services.filter { $0.lowercased().contains("wi-fi") || $0.lowercased().contains("wifi") }
        reordered.append(contentsOf: services.filter { !$0.lowercased().contains("wi-fi") && !$0.lowercased().contains("wifi") })
        return reordered
    }
    
    /// 应用新的网络服务顺序
    func applyNetworkServiceOrder(services: [String]) {
        // 构建networksetup命令参数
        var arguments = ["-ordernetworkservices"]
        
        // 处理服务名称，对包含空格的名称添加引号
        let quotedServices = services.map { service -> String in
            if service.contains(" ") {
                return "\"\(service)\""
            } else {
                return service
            }
        }
        
        arguments.append(contentsOf: quotedServices)
        
        // 通过网络请求发送调整网络服务顺序的指令
        sendNetworkRequest(to: "http://localhost:3000/api/reorder-network", requestBody: quotedServices.first ?? "Ethernet") {
            result in
            switch result {
            case .success(let response):
                print("网络请求成功: \(response)")
            case .failure(let error):
                print("网络请求失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 发送网络请求的方法
    func sendNetworkRequest(to urlString: String, requestBody priorityNetworkInterface: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "InvalidURL", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 请求体
        let requestBody: [String: Any] = [
            "action": "reorder_network",
            "priorityInterface": priorityNetworkInterface
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }

        // 在后台线程执行网络请求
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                completion(.failure(NSError(domain: "HTTPError", code: statusCode,
                                           userInfo: [NSLocalizedDescriptionKey: "HTTP错误，状态码: \(statusCode)"])))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "NoDataError", code: -1,
                                           userInfo: [NSLocalizedDescriptionKey: "未收到响应数据"])))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? String {
                    completion(.success(message))
                } else {
                    let responseString = String(data: data, encoding: .utf8) ?? "无法解析响应"
                    completion(.success(responseString))
                }
            } catch {
                let responseString = String(data: data, encoding: .utf8) ?? "无法解析响应"
                completion(.success(responseString))
            }
        }.resume()
    }
    
    /// 执行网络命令
    func executeNetworkCommand(arguments: [String], completion: ((String?) -> Void)? = nil) {
        DispatchQueue.global(qos: .utility).async {
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
        }
    }
    
    /// 设置以太网为首要网络服务
    func setEthernetAsPrimary() {
        DispatchQueue.global(qos: .utility).async {
            self.executeNetworkCommand(arguments: ["-listnetworkserviceorder"]) { [weak self] output in
                guard let self = self, let output = output else { return }
                let services = self.parseNetworkServices(from: output)
                print("原始网络服务列表: \(services)")
                
                // 重新排序网络服务列表，将WiFi移到首位
                let reorderedServices = self.reorderServicesWithEthernetFirst(services: services)
                print("排序后网络服务列表: \(reorderedServices)")
                
                // 应用新的网络服务顺序
                self.applyNetworkServiceOrder(services: reorderedServices)
            }
        }
    }

    /// 设置无线网为首要网络服务
    func setWifiAsPrimary() {
        DispatchQueue.global(qos: .utility).async {
            self.executeNetworkCommand(arguments: ["-listnetworkserviceorder"]) { [weak self] output in
                guard let self = self, let output = output else { return }
                let services = self.parseNetworkServices(from: output)
                print("原始网络服务列表: \(services)")
                
                // 重新排序网络服务列表，将WiFi移到首位
                let reorderedServices = self.reorderServicesWithWifiFirst(services: services)
                print("排序后网络服务列表: \(reorderedServices)")
                
                // 应用新的网络服务顺序
                self.applyNetworkServiceOrder(services: reorderedServices)
            }
        }
    }
}
