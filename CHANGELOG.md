# 更新记录

## 2.1.0

- 修复短列表、空列表及反复切页时的头部留白和位置对齐问题。
- 通过组件管理的底部 inset 补足短内容滚动范围，不再回写列表的真实 contentSize；关闭自动补足时也会处理超出滚动范围的位置。
- 新增 contentBottomInset(for:) 和 setContentBottomInset(_:for:)，用于区分业务底部遮挡与组件的自动补足量。
- keepsContentScrollPosition 统一控制切页及 updateLayouts() 的位置保持。头部尺寸变化时保留内容相对 tabStrip 的位置，并处理吸顶、半展开及短列表边界。
- 精简滚动协调状态，增加 64 项自动化测试，覆盖原生列表布局、切页、头部尺寸变化及重建等场景。

### 兼容性说明

- 以前 updateLayouts() 总会重置位置；现在 keepsContentScrollPosition 为 true 时会保留位置。默认 false 的重置行为不变，首次加载及 rebuild() 仍从初始位置开始。
- 位置保持适用于头部尺寸变化、子列表内容布局不变的场景，不负责数据增删或 cell 高度变化后的内容锚定。
- 动态增减业务底部 inset 时请使用上述接口，不要基于包含自动补足量的 contentInset.bottom 进行累计计算。关闭自动补足时，短列表可能通过展开头部回退到有效范围，不保证仍能吸顶。
