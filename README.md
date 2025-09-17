# Custom APB UART IP  
**Author:** Shrif Emad  

## 📌 Overview  
This project implements a **Universal Asynchronous Receiver/Transmitter (UART)** peripheral wrapped with an **AMBA APB (Advanced Peripheral Bus) interface**, designed to be integrated as part of a System-on-Chip (SoC).  

The design provides memory-mapped registers for UART control, status monitoring, data transfer, and baud rate configuration. It also ensures compliance with the APB protocol for reliable communication between the bus master and the UART core.  

---

## 🎯 Objectives  
- Implement a custom UART IP with APB slave interface.  
- Design and integrate the **UART Transmitter** and **UART Receiver**.  
- Provide register-based access to control and monitor UART.  
- Develop **self-checking testbenches** to verify the design.  
- Generate simulation results and validate correct operation.  

---

## 🏗️ Design Features  
### 1. **UART Core**  
- **Transmitter (TX):**  
  - Appends start and stop bits.  
  - Transmits data byte-by-byte with correct timing.  
  - Provides `tx_busy` and `tx_done` status signals.  

- **Receiver (RX):**  
  - Detects start bit and samples incoming data bits.  
  - Validates stop bit and checks for framing errors.  
  - Provides `rx_busy`, `rx_done`, and `rx_error` signals.  

### 2. **APB Slave Interface**  
- Fully compliant with **AMBA APB protocol**.  
- Handles both **read** and **write** transactions.  
- Provides a ready (`PREADY`) handshake signal.  
- FSM ensures proper transition between **IDLE → SETUP → ACCESS** states.  

### 3. **Register Map**  
| Address | Register    | Description |
|---------|------------|-------------|
| 0x0000  | CTRL_REG   | Control bits: `tx_en`, `rx_en`, `tx_rst`, `rx_rst` |
| 0x0001  | STATS_REG  | Status bits: `rx_busy`, `tx_busy`, `rx_done`, `tx_done`, `rx_error` |
| 0x0002  | TX_DATA    | UART transmit data |
| 0x0003  | RX_DATA    | UART received data |
| 0x0004  | BAUDIV     | Baud rate divisor (configurable) |

---

## 🧪 Verification Strategy  
- **Testbenches written in Verilog** for each module:  
  - UART Transmitter Testbench  
  - UART Receiver Testbench  
  - APB UART Wrapper Testbench  
- **Self-checking mechanisms** included for automated validation.  
- Simulation results confirm:  
  - Correct start/stop framing.  
  - Accurate baud rate timing.  
  - Proper APB read/write operations.  

---

## 📂 Repository Structure  
```
├── src      # RTL Verilog design files  
│   ├── uart_tx.v  
│   ├── uart_rx.v  
│   ├── apb_uart.v  
│
├── dv       # Verification (testbenches & .do files)  
│   ├── tb_apb_uart.v  
│
├── fpga     # FPGA implementation runs  
│   ├── synthesis scripts  
│   ├── constraints files  
│
├── docs     # Documentation (reports)  
│   ├── course_project.pdf   
```

---

## ⚡ Results  
- Successfully implemented and verified a **custom APB UART IP**.  
- UART communication confirmed via simulation at standard baud rates.  
- Fully functional APB register interface for easy SoC integration.  

---

## ✅ Conclusion  
This project demonstrates the complete flow of designing, integrating, and verifying a **custom UART IP with APB interface**. It not only strengthened my understanding of digital design and bus-based communication but also provided practical experience in RTL coding, testbench creation, and SoC peripheral design.  
