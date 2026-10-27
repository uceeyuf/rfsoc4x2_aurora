![语言](https://img.shields.io/badge/语言-verilog_(IEEE1364_2001)-9A90FD.svg) ![仿真](https://img.shields.io/badge/仿真-xsim-green.svg) ![部署](https://img.shields.io/badge/部署-vivado_2023.2-FF1010.svg) ![板卡](https://img.shields.io/badge/板卡-RFSoC_4x2-blue.svg) ![链路](https://img.shields.io/badge/链路-Aurora_64B66B_100G-orange.svg)

[English](#en) | [中文](#cn)

　

<span id="en">RFSoC 4x2 100G Aurora over QSFP28</span>
===========================

Aurora 64B/66B on the RFSoC 4x2 (XCZU48DR-FFVG1517-2-E) QSFP28 port: **four lanes at 25.78125 Gb/s (100G), streaming, full duplex**, loaded with PRBS31 at the full channel rate and checked bit by bit on the receive side. JTAG only: no PS software, the link is controlled and read through a VIO (`tests/aurora_test.tcl`).

The test setup is a 100GBASE-SR4 QSFP28 optical module (Intel SPTSBP2CLCKV) in optical self-loopback (an MPO loopback plug: TX lane l comes back on RX lane 3 - l). The GTs' near-end PMA loopback is selectable for a check without a module.

　

## Technical Features

* **156.25 MHz reference, fractional-N**: the QSFP28 reference clock of the RFSoC 4x2 is 156.25 MHz (MGTREFCLK0 of quad 128, AA33 / AA34). 25.78125 Gb/s is 165 times that, which the QPLL reaches only in fractional-N mode; the Aurora core offers integer multiples only (161.1328125 MHz). The core is therefore generated with its transceivers outside (`C_GTWIZ_OUT`) and the GT wizard is generated again with the board's clock: the Aurora core's own GT settings (GTY, 64B66B in the transceiver, 64-bit user data), QPLL0 fractional numerator 8388608 / 2^24 = 0.5, as the CMAC of [rfsoc4x2_100g_udp](https://github.com/uceeyuf/rfsoc4x2_100g_udp) on the same pins. The clock is routed north to the cage's channels X0Y4..X0Y7 (quad 129).
* **Full rate**: 256-bit streaming interface at the 402.83 MHz user clock; payload 4 x 25.78125 x 64 / 66 = 100.0 Gb/s.
* **PRBS31 at 256 bits a cycle**: x^31 + x^28 + 1, the next 256 bits from the previous 31 (`scripts/gen_prbs31.py` writes the table: every bit is the XOR of at most 9 state bits, two LUT levels at 402.83 MHz).
* **Checker**: self-synchronizing until 64 error-free words, then locked to its own sequence so that a bit error counts once (not three times through the feedback taps); pipelined population count of the 256 error bits; 48-bit counters of words, bit errors and words with errors; lock losses, soft errors, hard errors and channel drops.
* **Counters read without tearing**: the VIO (100 MHz) requests a snapshot, the user clock copies every counter at once and acknowledges; the rate is computed from the user clock cycles between snapshots.
* **Self test**: one bit flipped at the transmitter on request; the test script expects exactly one counted error.
* **Lane order**: Aurora 64B/66B deskews the four lanes but does not reorder them (the CMAC does, from its alignment markers). Through an SR4 module with an MPO loopback plug TX lane l comes back on RX lane 3 - l: the channel comes up, but the 256-bit words arrive with their four 64-bit lanes reversed. The checker can take the word reversed (VIO `rx_rev`); `tests/aurora_test.tcl` tries the straight order first and the reversed one if the checker does not lock. Between two boards over straight lanes no reversal is needed.
* **QSFP28 sideband**: ResetL high, LPMode low (high power: the lasers on), ModSelL high (no I2C); ModPrsL and IntL are read in the VIO.

　

## Test Results

Intel SPTSBP2CLCKV (100GBASE-SR4) with an MPO loopback plug, Vivado 2023.2:

| Test | Lane order | Checked rate | Bits | Bit errors | BER | Soft / hard errors, drops |
| :--- | :--------: | :----------: | :--: | :--------: | :-: | :-----------------------: |
| Optical loopback, 60 s | reversed (found automatically) | **99.837 Gb/s** | 6.008e12 | 0 | < 1.7e-13 | 0 / 0, 0 |
| GT near-end PMA loopback, 10 s | straight | 99.837 Gb/s | 1.015e12 | 0 | < 9.9e-13 | 0 / 0, 0 |

In both runs the injected error was counted once, and the checker lost lock 0 times.

Through the plug the checker locks only on the reversed lane order (TX lane l on RX lane 3 - l, as [rfsoc4x2_ibert](https://github.com/uceeyuf/rfsoc4x2_ibert) maps it). 99.837 Gb/s is the 100.0 Gb/s of payload less the clock-correction sequences the channel inserts.

　

## Build and Run

Vivado 2023.2. The prebuilt bitstream and probes file are in `prebuilt/`, so the board can be tested without building (Vivado Lab Edition is enough):

```
git clone https://github.com/uceeyuf/rfsoc4x2_aurora.git
cd rfsoc4x2_aurora
vivado -mode batch -source tests/aurora_test.tcl -tclargs 60          # through the QSFP28 module, 60 s
vivado -mode batch -source tests/aurora_test.tcl -tclargs 10 2        # GT near-end PMA loopback (no module needed)
```

Arguments: seconds, loopback (0 through the module, 2 near-end PMA), and the keywords `rev` / `norev` (the received lane order; default: straight, then reversed if the checker does not lock) and `noprog`. `tests/aurora_test.tcl` programs the FPGA, restarts the link (pma_init, then reset_pb), waits for channel up, finds the lane order, clears the counters, prints the checked rate, the bit errors and the BER once a second, then injects one error and checks that it is counted. The output is also written to `out/aurora_test.txt`.

Build from source (creates `build/`, copies the result to `prebuilt/`):

```
vivado -mode batch -source scripts/build.tcl -tclargs 16
vivado -mode batch -source scripts/program.tcl
```

Simulation of the PRBS31 source and checker (random valid gaps, lock, one injected error counted once):

```
xvlog -i rtl rtl/prbs31_tx.v rtl/prbs31_rx.v sim/tb_prbs31.v && xelab tb_prbs31 -R
```

| Directory      | Contents |
| :------------- | :------- |
| `rtl/`         | `fpga.v` (top: clocks, start-up, Aurora, traffic, counters, VIO), `prbs31_tx.v`, `prbs31_rx.v`, `prbs31_next.vh` (generated) |
| `ip/`          | the Aurora core, its GT wizard at 156.25 MHz, the VIO (Tcl) |
| `constraints/` | pins and clocks |
| `scripts/`     | `create_project.tcl`, `build.tcl`, `program.tcl`, `gen_prbs31.py` |
| `tests/`       | `aurora_test.tcl` |
| `prebuilt/`    | `rfsoc4x2_aurora.bit`, `rfsoc4x2_aurora.ltx` |

　

## Citation

If this work helps your research, please cite it:

```bibtex
@misc{yu2026rfsoc4x2_aurora,
    author = {Yijie Yu},
    title = {{RFSoC 4x2 100G Aurora 64B/66B over QSFP28}},
    year = {2026},
    howpublished = {\url{https://github.com/uceeyuf/rfsoc4x2_aurora}},
    note = {GitHub repository},
}
```

GitHub also offers the citation under **Cite this repository** (from [CITATION.cff](CITATION.cff)).

　

## License

BSD 3-Clause, Copyright (c) 2026 Yijie Yu. The Aurora 64B/66B, GT wizard and VIO cores are generated by Vivado from AMD IP at build time.

　

<span id="cn">RFSoC 4x2 100G Aurora（QSFP28）</span>
===========================

RFSoC 4x2（XCZU48DR-FFVG1517-2-E）QSFP28 口上的 Aurora 64B/66B：**4 路 25.78125 Gb/s（100G），流模式，全双工**。发送端以满信道速率灌 PRBS31，接收端逐比特校验。只用 JTAG：不需要 PS 软件，链路的控制和读数都通过 VIO（`tests/aurora_test.tcl`）。

测试环境是 100GBASE-SR4 QSFP28 光模块（Intel SPTSBP2CLCKV）光自环（MPO 回环头：TX 第 l 路回到 RX 第 3 - l 路）。也可以选 GT 的近端 PMA 回环，不插模块先自检。

　

## 技术特点

* **156.25 MHz 参考时钟，小数分频**：RFSoC 4x2 的 QSFP28 参考时钟是 156.25 MHz（quad 128 的 MGTREFCLK0，AA33 / AA34）。25.78125 Gb/s 是它的 165 倍，QPLL 只有在小数分频模式下才能得到；Aurora 核只提供整数倍（161.1328125 MHz）。所以 Aurora 核按"收发器放在核外"（`C_GTWIZ_OUT`）生成，GT wizard 用板上时钟重新生成：沿用 Aurora 核自己的 GT 设置（GTY、64B66B 在收发器里、64 bit 用户数据），QPLL0 小数分子 8388608 / 2^24 = 0.5，与 [rfsoc4x2_100g_udp](https://github.com/uceeyuf/rfsoc4x2_100g_udp) 在同一组引脚上的 CMAC 相同。参考时钟向北走到 QSFP 笼子的通道 X0Y4..X0Y7（quad 129）。
* **满速率**：256 bit 流接口，用户时钟 402.83 MHz；净荷 4 x 25.78125 x 64 / 66 = 100.0 Gb/s。
* **每拍 256 bit 的 PRBS31**：x^31 + x^28 + 1，由前 31 位直接算出后 256 位（表由 `scripts/gen_prbs31.py` 生成：每一位最多是 9 个状态位的异或，402.83 MHz 下两级 LUT）。
* **校验器**：先自同步，连续 64 个字无误后锁定到自己的序列，一个比特错误只计一次（不会经反馈抽头变成三个）；256 个误码位流水线计数；48 位计数器：字数、误码比特数、出错字数；另有失锁次数、软错误、硬错误、通道掉线计数。
* **计数器无撕裂读取**：VIO（100 MHz）请求快照，用户时钟域一次复制所有计数器并应答；速率由两次快照之间的用户时钟周期数算出。
* **自检**：可在发送端翻转一个比特；测试脚本要求正好计到一个错误。
* **lane 顺序**：Aurora 64B/66B 只做四路的去偏斜，不重排 lane（CMAC 会按对齐标记重排）。经过 SR4 模块和 MPO 回环头时，TX 第 l 路回到 RX 第 3 - l 路：通道能建立，但 256 bit 字里四个 64 bit 的 lane 是倒序的。校验器可以把字倒过来再比（VIO `rx_rev`）；`tests/aurora_test.tcl` 先试正序，锁不上再试倒序。两块板之间用直通 lane 连接时不需要倒序。
* **QSFP28 控制脚**：ResetL 拉高，LPMode 拉低（高功率模式：激光打开），ModSelL 拉高（不用 I2C）；ModPrsL 和 IntL 从 VIO 读。

　

## 测试结果

Intel SPTSBP2CLCKV（100GBASE-SR4）加 MPO 回环头，Vivado 2023.2：

| 测试 | lane 顺序 | 校验速率 | 比特数 | 误码比特 | 误码率 | 软 / 硬错误、掉线 |
| :--- | :-------: | :------: | :----: | :------: | :----: | :---------------: |
| 光回环，60 秒 | 倒序（自动识别） | **99.837 Gb/s** | 6.008e12 | 0 | < 1.7e-13 | 0 / 0、0 |
| GT 近端 PMA 回环，10 秒 | 正序 | 99.837 Gb/s | 1.015e12 | 0 | < 9.9e-13 | 0 / 0、0 |

两次测试中注入的错误都正好计到一次，校验器失锁 0 次。

经过回环头时校验器只在 lane 倒序下锁定（TX 第 l 路回到 RX 第 3 - l 路，与 [rfsoc4x2_ibert](https://github.com/uceeyuf/rfsoc4x2_ibert) 测出的映射一致）。99.837 Gb/s 是 100.0 Gb/s 净荷减去通道插入的时钟补偿序列。

　

## 构建与运行

Vivado 2023.2。`prebuilt/` 里有现成的位流和探针文件，不构建也能直接上板测试（Vivado Lab Edition 就够）：

```
git clone https://github.com/uceeyuf/rfsoc4x2_aurora.git
cd rfsoc4x2_aurora
vivado -mode batch -source tests/aurora_test.tcl -tclargs 60          # 经过 QSFP28 模块，60 秒
vivado -mode batch -source tests/aurora_test.tcl -tclargs 10 2        # GT 近端 PMA 回环（不需要模块）
```

参数依次是：秒数、回环（0 经过模块，2 近端 PMA），以及关键字 `rev` / `norev`（接收 lane 顺序；默认先正序，校验器锁不上再倒序）和 `noprog`。`tests/aurora_test.tcl` 下载 FPGA，重启链路（先 pma_init，再 reset_pb），等通道建立，确定 lane 顺序，清零计数器，每秒打印校验速率、误码比特和误码率，最后注入一个错误并确认被计到。输出同时写到 `out/aurora_test.txt`。

从源码构建（生成 `build/`，结果复制到 `prebuilt/`）：

```
vivado -mode batch -source scripts/build.tcl -tclargs 16
vivado -mode batch -source scripts/program.tcl
```

PRBS31 发生器和校验器的仿真（随机空拍、锁定、注入的一个错误只计一次）：

```
xvlog -i rtl rtl/prbs31_tx.v rtl/prbs31_rx.v sim/tb_prbs31.v && xelab tb_prbs31 -R
```

| 目录           | 内容 |
| :------------- | :--- |
| `rtl/`         | `fpga.v`（顶层：时钟、上电时序、Aurora、数据、计数器、VIO）、`prbs31_tx.v`、`prbs31_rx.v`、`prbs31_next.vh`（生成） |
| `ip/`          | Aurora 核、156.25 MHz 的 GT wizard、VIO（Tcl） |
| `constraints/` | 引脚与时钟 |
| `scripts/`     | `create_project.tcl`、`build.tcl`、`program.tcl`、`gen_prbs31.py` |
| `tests/`       | `aurora_test.tcl` |
| `prebuilt/`    | `rfsoc4x2_aurora.bit`、`rfsoc4x2_aurora.ltx` |

　

## 引用

如果这个项目对你的研究有帮助，请引用：

```bibtex
@misc{yu2026rfsoc4x2_aurora,
    author = {Yijie Yu},
    title = {{RFSoC 4x2 100G Aurora 64B/66B over QSFP28}},
    year = {2026},
    howpublished = {\url{https://github.com/uceeyuf/rfsoc4x2_aurora}},
    note = {GitHub repository},
}
```

GitHub 仓库页的 **Cite this repository** 也提供同样的引用（来自 [CITATION.cff](CITATION.cff)）。

　

## 许可证

BSD 3-Clause（版权所有 (c) 2026 Yijie Yu）。Aurora 64B/66B、GT wizard 和 VIO 核在构建时由 Vivado 从 AMD IP 生成。
