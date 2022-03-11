# Django Auto

[English](README.md)

在Linux服务器上自动部署Django项目。


## 项目开发

* 创建一个Django项目
* 修改settings以自动切换develop环境和product环境
  * 删除settings.py
  * 创建settings目录，包含`__init__py`, `base.py`, `develop.py`, `product.py`。配置文件的内容参考[settings](django/settings/)。
* 修改wsgi.py以适应product环境(推荐)。配置文件内容参考[wsgi.py](django/wsgi.py)。

## 部署

### 环境需求

* Debian 11
* 英特网连接
* django > 3.2
* mysqlclient > 2.1
* 使用具有sudo权限的普通用户执行setup

### 执行安装和部署

1. 拷贝或分发你的Django项目目录到Linux服务器用户目录。
2. 执行setup.sh。

```bash
git clone https://github.com/hdaojin/django-auto.git
cd django-auto
bash script/setup.sh 
```

## 问题和建议

* [GitHub Issues](https://github.com/hdaojin/itnsa/issues)
* Email: hdaojin at hotmail.com

## 贡献代码

1. 在GitHub上注册一个账号 
2. Fork本项目
3. 从你的账号克隆项目到本地：`git clone https://github.com/your_account/itnsa.git`
4. 创建一个功能分支：`git checkout -b feature/AmazingFeature`
5. 在本地进行修改
6. 测试和提交你的改变: `git commit -a -m 'Add some AmazingFeature'`
7. 推送分支:  `git push origin feature/AmazingFeature`
8. 从你的GitHub fork创建一个Pull Request(PR)(到你的fork页面，点击“Pull Request”。你可以为你的提案添加一些描述信息。)