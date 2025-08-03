const http = require('http');
const { exec } = require('child_process');
const port = 3000;

// 解析 JSON 请求体的辅助函数
function parseJson(body) {
  try {
    return JSON.parse(body);
  } catch (error) {
    return null;
  }
}

// 创建服务器
const server = http.createServer((req, res) => {
  // 设置 CORS 头部
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  // 处理 OPTIONS 请求
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // 处理重新排序网络服务的请求
  if (req.method === 'POST' && req.url === '/api/reorder-network') {
    let body = '';

    // 接收请求体数据
    req.on('data', (chunk) => {
      body += chunk;
    });

    // 数据接收完毕
    req.on('end', () => {
      const requestBody = parseJson(body);
      console.log('收到重新排序网络服务的请求:', requestBody);

      // 调用 shell 脚本执行网络服务排序
      exec('sudo /bin/bash ~/Desktop/code/SDK/monitorbar/scripts/reorder_network_services.sh',
        (error, stdout, stderr) => {
          if (error) {
            console.error(`执行脚本错误: ${error}`);
            res.writeHead(500, { 'Content-Type': 'application/json' });
            return res.end(JSON.stringify({
              success: false,
              message: `执行脚本错误: ${error.message}`
            }));
          }

          if (stderr) {
            console.error(`脚本 stderr: ${stderr}`);
          }

          console.log(`脚本 stdout: ${stdout}`);
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({
            success: true,
            message: '网络服务顺序已调整',
            output: stdout
          }));
        });
    });
  } else {
    // 处理其他请求
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      success: false,
      message: '请求路径不存在'
    }));
  }
});

// 启动服务器
server.listen(port, () => {
  console.log(`服务器运行在 http://localhost:${port}`);
});