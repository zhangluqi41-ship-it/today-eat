# 今晚吃什么 · 项目说明

一个解决「今晚吃什么」的菜谱 App。菜谱库来自你给的那张表格：**6 个分类、213 道菜**（去掉了重复项），
每道菜都有配料、分步做法、关键窍门、耗时/难度/辣度，全部可以在 App 里改。

仓库里有两套东西，**先看你要哪一种**：

| 产物 | 在哪 | 用途 |
|---|---|---|
| 网页版（单文件） | `dist/今晚吃什么.html` | 现在就能用。手机浏览器打开，可「添加到主屏幕」，数据存本机 |
| iPhone 原生版（SwiftUI） | `Sources/` + `project.yml` + `.github/workflows/build.yml` | 按交接文档的铁律做的真正原生 App，靠 GitHub Actions 出无签名 IPA |

两边共用同一份菜谱数据：`Sources/Resources/SeedRecipes.json`。

---

## 一、功能

**今晚（抽签）**
- 老虎机式抽签：菜名快速滚动后停在结果上，带触感反馈
- 「就它了」= 记一笔做饭记录，同时可以直接进详情开做
- 三选一：给三个候选，降低「抽到不想吃」的反复
- 一键把这一周晚餐排满
- 抽签范围可调：荤/素/汤/蛋/豆、时间上限、辣度上限、跳过最近 N 天吃过的、只看收藏
- 忌口：配料里出现忌口词（比如香菜）就直接不进候选池

**菜谱**
- 213 道菜，按 6 个分类，搜索支持菜名 / 食材 / 标签
- 详情页：主料/调料分开、点一下打勾、改份量自动换算用量
- 完整编辑：菜名、分类、类型、耗时、难度、辣度、标签、配料、步骤、窍门
- 新增、删除、左滑收藏、分享文字版（复制就能发微信）

**厨房**
- 录入冰箱里现有的食材，按「还差几样」排菜，只算主料（调料默认家里有）
- 差 0 样直接标「齐了」

**清单**
- 从任意菜谱一键把配料加进购物清单，同名自动合并用量
- 勾选已买、清空已买
- 这周菜单：7 天 × 午/晚，可手动排，也可自动排满

**做饭模式**
- 一步一屏的大字，上一步/下一步
- 步骤里写了「10 分钟」就出现「计时 10 分钟」，带进度条，结束提醒 + 震动

**我的**
- 菜谱数、做过次数、平均评分
- 收藏、做饭记录（可打 1–5 星）、自己写的菜
- 设置：默认份量、时间上限、辣度上限、忌口、只从收藏里抽
- 数据：导出 JSON 备份 / 从备份恢复 / 恢复内置菜谱 / 清空记录

---

## 二、网页版怎么用（最快）

1. 把 `dist/今晚吃什么.html` 这个文件发到手机（微信文件传输助手、iCloud、邮件都行）
2. 手机上用浏览器打开
3. 想当 App 用：Safari 分享 → **添加到主屏幕**

注意：网页版的数据存在浏览器 localStorage 里，**换浏览器/清缓存会丢**，重要内容用「我的 → 导出备份文件」。

---

## 三、iPhone 原生版怎么出包

你需要：一个 GitHub 账号（公开仓库免费）、一台能上网的电脑。**不需要 Mac。**

1. 在 GitHub 新建一个**公开**仓库，把本目录所有文件推上去（`.github/` 别漏）
2. 推到 `main` 分支后，Actions 里会自动跑 `Build iOS IPA`
3. 跑完在 Actions → 这次运行 → Artifacts 下载 `TodayEat-ipa`
4. 解压得到两个包：
   - `TodayEat-aisi.ipa` → 给**爱思助手**（bundle id 无后缀 `com.siye.todayeat`）
   - `TodayEat-sidestore.ipa` → 给 **SideStore**（bundle id 连字符 `com.siye.today-eat`）
5. 装机，打开

### 三条必须记住的规则

- **认准一个渠道，以后别换。** 两个包的 bundle id 不同 = 两个沙盒。爱思版换成 SideStore 版，看起来就是「数据全丢」。
- **升级一律装同一个 IPA 覆盖，不要卸载重装。** 卸载会连沙盒一起删。
- **版本号只增不减。** CI 里已用 `MARKETING_VERSION=1.0.<构建号>`，每次自动 +1，不用手动改。

如果装完发现桌面多出一个图标：数据没丢，在旧容器里，删掉新装的那个就行。

---

## 四、菜谱数据怎么改

数据源是 `Data/` 下的 6 个文本文件，格式很轻：

```
@ 菜名 | 分类key | 类型 | 耗时 | 难度 | 辣度 | 标签,标签
- 主料名 | 用量        （"-" 主料）
+ 调料名 | 用量        （"+" 调料）
> 一步做法
> 再一步
! 一句话窍门
```

改完后跑：

```bash
python Scripts/build_seed.py
```

它会校验（菜名唯一、配料够、步骤够、耗时范围）并重新生成 `Sources/Resources/SeedRecipes.json`。
**App 只在镜像包里带这份 JSON，所以改数据必须重跑脚本再出包。**

网页版也要重新打一次：

```bash
python Scripts/build_web.py
```

图标是脚本画的，想换配色改 `Scripts/make_icon.py` 再跑一次。

CI 里有一条「校验菜谱数据」：如果 `Data/` 改了但忘了重跑脚本，构建会直接失败，避免线上包和源文件不一致。

---

## 五、对照交接文档的自检

| 铁律 | 本项目的做法 |
|---|---|
| 按钮只用系统第一方样式 | 全项目唯一按钮样式 `liquidGlassButton()`：iOS 26 走 `.glass`，低版本 `.bordered`，零自绘 |
| 卡片只用 `GroupBox` | 所有卡片都是 `GroupBox`，没有 `RoundedRectangle` 当卡片 |
| 导航必须 TabBar | 5 个 Tab：今晚 / 菜谱 / 厨房 / 清单 / 我的，无汉堡菜单 |
| 数据放 Application Support | `Application Support/TodayEat/data.json`，写盘带 `.completeFileProtectionUntilFirstUserAuthentication` |
| catch 必须收窄 | 只有 `DecodingError` 判损坏（改名 `.corrupt.json`），权限/IO 失败只提示可重试，绝不覆盖 |
| 加载没成功不许写盘 | `loadSucceeded` 门闩，未置位 `persist()` 直接 return |
| 重试机制 | 首屏 `onAppear` + `scenePhase == .active` 调 `retryLoadIfNeeded()` |
| 不长按菜单 | 全部用 `⋯` 菜单栏或左滑操作，无 `contextMenu` |
| 一次只改一件事 | 本次交付为首次完整实现，后续改动按单点提交 |
| 版本号每个 target 都改 | 单 target；CI 用构建号统一 +1 |
| 必须有 AppIcon | `AppIcon-1024.png`，脚本生成，无第三方素材 |
| 触控 ≥44pt、间距 8pt 增量 | 底部操作条、列表行、按钮均 ≥44 |
| 不硬编码十六进制（品牌色除外） | 只用语义色 `.primary/.secondary/.tertiary` + `Color.accentColor`（品牌橙） |

已知限制：

- 原生版还没在真机上编译过（这台机器没有 Mac）。CI 第一次跑如果报错，把日志贴回来，按「一次只改一处」修。
- `.buttonStyle(.glass)` 需要 Xcode 26 / iOS 26 SDK；CI 用的是 `macos-26`，满足。
- 份量换算是「数字开头的用量」才换（`200 克`→`400 克`），`半根`、`适量` 原样保留，这是刻意的，不猜。
- 原生版暂未做小组件、通知、iCloud 同步；数据只在本机。

---

## 六、目录

```
Data/                     菜谱源文件（6 个分类）
Scripts/build_seed.py     编译 + 校验 → SeedRecipes.json
Scripts/build_web.py      打网页版单文件
Scripts/make_icon.py      画 App 图标
Sources/App               入口
Sources/Models            数据模型
Sources/Store             数据层（持久化 / 抽签 / 清单 / 计划）
Sources/Views             各页面
Sources/Resources         SeedRecipes.json + Assets
project.yml               XcodeGen 工程声明
.github/workflows/build.yml  云端出包
dist/今晚吃什么.html       网页版成品
web/app.html              网页版模板
```
