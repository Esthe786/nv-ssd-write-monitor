# NVIDIA SSD Write Monitor

ใช้เฝ้าดูว่า `NVDisplay.Container.exe` (service NVIDIA Display Container LS) เขียนข้อมูลลง SSD มากผิดปกติหรือไม่ มีรายงานว่าไดรเวอร์ GeForce **621.14 / 621.24** เขียนไฟล์ `nvlog.nvlgstg` ตลอดเวลา ได้ถึงหลาย GB ต่อชั่วโมง

A small read-only tool that measures how much `NVDisplay.Container.exe` writes, to check for the reported GeForce 621.14 / 621.24 constant-SSD-write bug.

## วิธีใช้ / Usage

1. ดาวน์โหลด `nvwatch.bat` กับ `nvwatch.ps1` มาไว้ในโฟลเดอร์เดียวกัน
2. ดับเบิลคลิก `nvwatch.bat` จะเปิดหน้าต่าง cmd ขึ้นมา ปล่อยเครื่องไว้เฉยๆ แล้วรอดูผล
3. กด Ctrl+C เมื่อต้องการหยุด

ตั้งค่าเพิ่มได้ เช่น เก็บค่าทุก 30 วินาที และให้หยุดเองหลังครบ 6 ชั่วโมง:

```
nvwatch.bat -IntervalSec 30 -Hours 6
```

## สิ่งที่โปรแกรมแสดง / Output

- รุ่น GPU และเวอร์ชันไดรเวอร์ พร้อมเตือนถ้าเป็นรุ่นที่มีรายงานว่ามีปัญหา
- ยอดที่ process เขียนไปแล้วตั้งแต่เปิดเครื่อง ตัวเลขนี้จะสูงกว่าปกติเพราะรวมช่วงบูตด้วย
- ทุกครั้งที่เก็บค่า: ปริมาณที่เขียนเพิ่ม (MB) และอัตราต่อชั่วโมงโดยประมาณ แยกสีตามระดับ
- **ทุกชั่วโมง** สรุปว่าชั่วโมงนั้นเขียนไปกี่ MB ค่าเฉลี่ยต่อชั่วโมง และคาดการณ์ GB ต่อวัน
- ถ้า service restart (PID เปลี่ยน) โปรแกรมจะตรวจเจอและนับต่อให้เอง
- บันทึก log ลงไฟล์ `nvwatch-<เวลา>.csv` และ `nvwatch-<เวลา>-summary.txt` ไว้ข้างสคริปต์

| อัตรา / Rate | ผล / Verdict |
|---|---|
| ≤ 50 MB/h | NORMAL (เทียบได้กับ 621.01 ซึ่งเขียน < 24 MB/h) |
| ≤ 1000 MB/h | ELEVATED |
| > 1000 MB/h | HIGH — น่าจะโดนบั๊ก (621.14 ~6 GB/h, 621.24 สูงสุด ~30 GB/h) |

ให้ดูค่าตอนเปิดเครื่องทิ้งไว้เฉยๆ ถ้ากำลังเล่นเกมหรืออัดวิดีโอ ตัวเลขจะสูงขึ้นตามปกติ

## หมายเหตุ / Notes

- สคริปต์แค่**อ่าน**ตัวนับ I/O ของ process ไม่แก้ไขอะไรในเครื่อง และไม่ต้องรันแบบ admin
- ค่าที่วัดคือ `WriteTransferCount` ซึ่งนับการเขียนทุกแบบของ process ไม่ได้นับเฉพาะการเขียนลงดิสก์ ตัวเลขจึงอาจสูงกว่าที่ลง SSD จริงเล็กน้อย
- ใช้ได้กับ Windows 10/11 ที่มี PowerShell 5.1 ขึ้นไป

## ข้อมูลอ้างอิง / References

- [Overclockzone (TH)](https://www.overclockzone.com/view-18757)
- [Reddit r/pcmasterrace](https://www.reddit.com/r/pcmasterrace/comments/1xzbgal/it_seems_nvidia_gpu_drivers_also_constantly_write/)
- [NVIDIA 621.24 feedback thread](https://www.nvidia.com/en-us/geforce/forums/game-ready-drivers/13/592767/geforce-grd-62124-feedback-thread-released-111226/3633670/)

## License

MIT
