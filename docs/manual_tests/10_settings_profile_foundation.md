# Sprint 6A Settings & Profile Foundation 手动测试

1. 启动 App。
2. 确认主导航显示 Today、Journal、Plan、Health、Growth。
3. 确认主导航不再显示 Profile。
4. 点击右上角 Settings 图标。
5. 确认进入 Settings 页面。
6. 查看账号与同步卡片，确认显示“本地模式”“未登录”“跨端同步暂未启用”。
7. 点击“账号互联”，确认弹出说明 Dialog，且没有真实登录操作。
8. 点击个人资料入口，进入 Profile。
9. 修改昵称并保存。
10. 返回 Settings，确认名称已经更新。
11. 查看设备 ID，确认只显示短格式。
12. 确认页面没有显示虚假的“已登录”或“已同步”。
13. 返回主界面并切换 Today、Journal、Plan、Health、Growth，确认导航正常。
14. 关闭并重启 App，确认 Profile 修改仍然存在。
15. 确认数据库 schemaVersion 仍为 3。
