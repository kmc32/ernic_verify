请使用标准uvm框架，搭建xilinx ernic version 4.0 IP的验证环境，测试当前路径下test_points.md的功能点，工程需要符合以下要求：
- 使用uvm 1.2
- 需要直接验证ernic ip，而不是这个ip的等价rtl模型
- 语法符合vcs 2018.09-SP2
- 使用vivado 2022.2
- ernic是加密ip，makefile需要先编译出vcs可用的替代组件，然后拿这个组件和UVM验证环境一起编译