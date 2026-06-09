

#include <SoftwareSerial.h>

#include <PS2Keyboard.h>

#include <LinkedList.h>
#include <PS2MouseHandler.h>

#define MDATA 4
#define MCLK 5
#define KDAT 6
#define KCLK 3
#define STX 8
#define SRX 9

//Define archimedes codes
#define HRST 0xFF
#define RAK1 0xFE
#define RAK2 0xFD
#define NBYTE 0x00
//RQPD Unused??
//PDAT w/ RQPD
#define RQID 0x20
#define KBID 0xAF // Might work idk its meant to be 10xx xxxx
#define KDDA 0xC0 //1100 = key down, 1 byte = KDDA+row, 2 byte = KDDA+column
#define KUDA 0xD0 //Key up same idea
#define RQMP 0x22 //Mouse data request
// Required mouse data. Byte 1 = 0 + signed 7 bit int for X; Byte 2 = 0+ signed 7 bit int for y
#define BACK 0x3F
#define NACK 0x30
#define SACK 0x31
#define MACK 0x32
#define SMAK 0x33
#define PRST 0x21 //does Nothing

PS2MouseHandler mouse(MCLK, MDATA, PS2_MOUSE_REMOTE);
PS2Keyboard keyboard;
typedef struct {
  uint8_t rows[136];
  uint8_t columns[136];
} ArchiKeymap_t;
LinkedList<int> heldKeys = LinkedList<int>();
bool PrevMB[3] = {false,false,false};

const ArchiKeymap_t  keymap_Archi = {
  {
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x01, 0x00, 
    0x00, 0x05, 0x04, 0x00, 0x03, 0x02, 0x01, 0x00, 0x00, 0x00, 0x04, 0x03, 0x03, 0x02, 0x01, 0x00, 
    0x00, 0x05, 0x04, 0x03, 0x02, 0x01, 0x01, 0x00, 0x00, 0x05, 0x05, 0x03, 0x02, 0x02, 0x01, 0x00, 
    0x00, 0x05, 0x05, 0x04, 0x04, 0x02, 0x01, 0x00, 0x00, 0x00, 0x05, 0x04, 0x02, 0x01, 0x01, 0x00, 
    0x00, 0x05, 0x04, 0x02, 0x02, 0x01, 0x01, 0x00, 0x00, 0x05, 0x05, 0x04, 0x04, 0x03, 0x01, 0x00, 
    0x00, 0x00, 0x04, 0x00, 0x03, 0x01, 0x00, 0x00, 0x05, 0x05, 0x04, 0x03, 0x00, 0x03, 0x00, 0x00, 
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x04, 0x03, 0x00, 0x00, 0x00, 
    0x06, 0x06, 0x05, 0x04, 0x04, 0x03, 0x00, 0x02, 0x00, 0x04, 0x05, 0x03, 0x02, 0x03, 0x00, 0x00, 
    0x00, 0x00, 0x00, 0x00
  },
  {
    0x00, 0x09, 0x00, 0x05, 0x03, 0x01, 0x02, 0x0c, 0x00, 0x0a, 0x08, 0x06, 0x04, 0x06, 0x00, 0x00, 
    0x00, 0x00, 0x0c, 0x00, 0x0b, 0x07, 0x01, 0x00, 0x00, 0x00, 0x0e, 0x0d, 0x0c, 0x08, 0x02, 0x00, 
    0x00, 0x00, 0x0f, 0x0e, 0x09, 0x04, 0x03, 0x00, 0x00, 0x0f, 0x01, 0x0f, 0x0b, 0x0a, 0x05, 0x00, 
    0x00, 0x03, 0x02, 0x01, 0x00, 0x0c, 0x06, 0x00, 0x00, 0x00, 0x04, 0x02, 0x0d, 0x07, 0x08, 0x00, 
    0x00, 0x05, 0x03, 0x0e, 0x0f, 0x0a, 0x09, 0x00, 0x00, 0x06, 0x07, 0x04, 0x05, 0x00, 0x0b, 0x00, 
    0x00, 0x00, 0x06, 0x00, 0x01, 0x0c, 0x00, 0x00, 0x0d, 0x08, 0x07, 0x02, 0x00, 0x03, 0x00, 0x00, 
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0e, 0x00, 0x00, 0x0a, 0x00, 0x08, 0x07, 0x00, 0x00, 0x00, 
    0x05, 0x06, 0x0b, 0x09, 0x0a, 0x08, 0x00, 0x02, 0x0b, 0x0b, 0x0c, 0x0a, 0x04, 0x09, 0x0e, 0x00, 
    0x00, 0x00, 0x00, 0x07
  }
    
};

   
int mouseState = 0;
int ackCode = 0x00;
int tempKBID = 0x81;
// //0 - NACK - Only RQMP, No Keyboard.
// //1 - SACK - Only RQMP, Yes Keyboard
// //2 - MACK - Only non zero X OR Y, No Keyboard
// //3 - SMAK - Both MACK AND SACK
const PROGMEM int ArchiExtended[14][3] = {{0xE014, 0x06,0x01},{0xE011,0x06, 0x00}, {0xE070, 0x01, 0x0F}, {0xE06C, 0x02, 0x00}, {0xE07D,0x02, 0x01}, {0xE071, 0x03, 0x04}, {0xE069,0x03,0x05}, 
{0xE07A, 0x03, 0x06}, {0xE075, 0x05,0x09}, {0xE06B, 0x06, 0x02}, {0xE072, 0x06, 0x03}, {0xE074, 0x06, 0x04}, {0xE04A, 0x02, 0x03}, {0xE05A, 0x06, 0x07}};

/*Quick note on Key changes
Pressing end will press copy. To press end actually press Shift+End
Hashtag key gives hastag
To get tilda (~) press Shift + ` (The one under escape)*/
SoftwareSerial archiSerial =  SoftwareSerial(SRX, STX, true);
void setup() {
  // put your setup code here, to run once:
  pinMode(SRX, INPUT);
  pinMode(STX, OUTPUT);

  archiSerial.begin(31250);

  // int abc = mouse.initialise();
  //keyboard.begin(KDAT, KCLK);
  int a = reset(true,true);
  while (a == -1) {
    a = reset(true,true);
  }


  mouse.initialise();
  keyboard.begin(KDAT, KCLK);
  pinMode(13, OUTPUT);
}

int reset(bool selfInit, bool firstTime) {
  // Keyboard sends HRST and waits for ARM reply
  
  int code;
  archiSerial.write(HRST);
  code = readCodeBlocking(true);
  if (selfInit) {
    while (code == HRST) {
      writeCodeWait(HRST);
      code = readCodeBlocking(true);
    }
  }
  if (code == RAK1) {
    
    writeCodeWait(RAK1);
  } else {
    return -1;
  }
  code = readCodeBlocking(false);
  if (code == RAK2) {

    writeCodeWait(RAK2);
  } else {
    return -1;
  }
  code = readCodeBlocking(false);
  

  if (code == NACK) { // Send deletes to clear CMOS
    mouseState = 0;
    code = readCodeBlocking(false);
    if(code == RQID) {
      writeCodeWait(tempKBID);
      code = readCodeBlocking(true);
      if (code == HRST) {
        return -1;
      } 
      
    }
    
  }

  
  if (code >> 4 == 0x00) { // Check LED set
    code = readCodeBlocking(false);
  }

  if (code == SMAK) {
    mouseState = 3;
  }
  if (code == SACK) {
    mouseState = 1;
    if (firstTime) {
      writeCodeWait((KDDA | 0x03));
      code = readCodeBlocking(false);
      if (code == BACK) {
        writeCodeWait((KDDA | 0x04));
        code = readCodeBlocking(false);

      }
    }
  }
  if (code == MACK) {
    mouseState = 2;
  }

}
int loopCode;
void loop() {
  loopCode = readCodeNonBlocking(false);
  
  if (mouseState == 3 || mouseState == 1) {
    mouse.get_data();
    int x = mouse.x_movement();
    int y = mouse.y_movement();
    if (x != 0 || y != 0) {
      mousePos(x, y);
    }
  }

  if (mouseState == 3 || mouseState == 2) {
    bool mb0 = mouse.button(0);
    bool mb1 = mouse.button(1);
    bool mb2 = mouse.button(2);

    if (mb0 != PrevMB[0]) {
      sendToArchi(0x07, 0x00, !mb0);
      PrevMB[0] = mb0;
    }
    if (mb1 != PrevMB[1]) {
      sendToArchi(0x07, 0x01, !mb1);
      PrevMB[1] = mb1;
    }
    if (mb2 != PrevMB[2]) {
      sendToArchi(0x07, 0x02, !mb2);
      PrevMB[2] = mb2;
    }

    SendKeys();
  }

  
}

int mousePos(int x,int y) {
      ackCode = -1;
      int tempCode = -1;
      // Send X
      writeCodeWait(encode7bit(x));
      ackCode = readCodeBlocking(false); // BACK
      while (ackCode != BACK) {
        if (ackCode == HRST) {
          reset(false, false); // Host Reset condition
          return -1;
        } else if (ackCode == RQMP) {
          // handle RQMP condition
          tempCode = mousePos(mouse.x_movement(), mouse.y_movement());
        }
        ackCode = readCodeBlocking(false);
      }
      writeCodeWait(encode7bit(y)); // send Y
      ackCode = readCodeBlocking(false);
      while (ackCode != NACK && ackCode != MACK && ackCode != SACK &&
             ackCode != SMAK) {
        if (ackCode == HRST) {
          reset(false, false); // Host Reset condition
          return -1;
        } else if (ackCode == RQMP) {
          // handle RQMP condition
          tempCode = mousePos(mouse.x_movement(), mouse.y_movement());
        }
        ackCode = readCodeBlocking(false);
      }
      //Possible states:
      if (ackCode == SACK) {
        mouseState = 1;

      }else if (ackCode == MACK){
        mouseState = 2;
      }else if (ackCode == SMAK){
        mouseState = 3;
      }else if (ackCode == NACK){
        mouseState = 0;
      }
      return tempCode;
}
  

int SendKeys() {
  ackCode = 0x00;
  int tempCode = NULL;
  int scanVal;
  bool extended = false;
  bool breakCode = false;
  bool makePrnt = false;
  bool breakPrnt = false;

  // --- 1. Get the next valid scan code ---
  if (!keyboard.available()) return NULL;


  scanVal = keyboard.readScanCode();
  if (scanVal == 0x00) return NULL;
 // filter out stray 0s early

  // Skip repeat events (keys already held)
  bool inArray = false;
  for (int i = 0; i < heldKeys.size(); i++) {
    if (heldKeys.get(i) == scanVal) {
      inArray = true;
      break;
    }
  }

  // --- 2. Handle extended codes (0xE0 prefix) ---
  if (scanVal == 0xE0) {
    extended = true;
    while (scanVal == 0) {
        scanVal = keyboard.readScanCode();
    }
    

    // Handle Print Screen make code
    if (scanVal == 0x12) {
      makePrnt = true;
      // Clear rest of sequence
      int tempVal = keyboard.readScanCode();
      while (tempVal != 0xE0) {
        tempVal = keyboard.readScanCode();
      }
      tempVal = keyboard.readScanCode(); // E0
      while (tempVal != 0x7C) {
        tempVal = keyboard.readScanCode();
      } // 7C
    }
  }

  // --- 3. Handle break codes (0xF0 prefix) ---
  if (scanVal == 0xF0) {
    breakCode = true;
    scanVal = keyboard.readScanCode();
    while (scanVal == 0x00) {
        scanVal = keyboard.readScanCode();
    }

    // Handle Print Screen break code
    if (extended && scanVal == 0x7C) {
      breakPrnt = true;
      // Clear rest of sequence
      keyboard.readScanCode(); // E0
      keyboard.readScanCode(); // F0
      keyboard.readScanCode(); // 12
    }
  }

  // --- 4. Build full key code (with extended prefix) ---
  int fullCode = extended ? ((0xE0 << 8) | scanVal) : scanVal;
  if (fullCode == 0xE07C) fullCode = 0xE012; // normalize Print Screen

  // --- 5. Handle key release (break) ---
  if (breakCode) {
    for (int i = 0; i < heldKeys.size(); i++) {
      if (heldKeys.get(i) == fullCode) {
        heldKeys.remove(i);
        break;
      }
    }
    return handleKeySend(fullCode, extended, true);
  } else {
    // --- 6. Handle key press (make) ---
    for (int i = 0; i < heldKeys.size(); i++) {
      if (heldKeys.get(i) == fullCode) return NULL; // already held
    }

    heldKeys.add(fullCode);
    return handleKeySend(fullCode, extended, false);
  }

  
}


int handleKeySend(int fullCode, bool extended, bool isBreak) {
  int tempCode = NULL;
  int rowToSend = NULL;
  int colToSend = NULL;

  if (extended) {
    // Handle special Print Screen codes
    if (fullCode == 0xE012) {
      rowToSend = 0x00;
      colToSend = 0x0D;
    } else {
      for (int i = 0; i < 13; i++) {
        if (fullCode == ArchiExtended[i][0]) {
          rowToSend = ArchiExtended[i][1];
          colToSend = ArchiExtended[i][2];
          break;
        }
      }
    }
  } else {
    rowToSend = keymap_Archi.rows[fullCode];
    colToSend = keymap_Archi.columns[fullCode];
  }

  if (isBreak) {
    ackCode = sendToArchi(rowToSend, colToSend, true);
  } else {
    ackCode = sendToArchi(rowToSend, colToSend, false);
  }
  

  
  if (ackCode == SMAK) mouseState = 3;
  else if (ackCode == SACK) mouseState = 1;
  else if (ackCode == MACK) mouseState = 2;
  else if (ackCode == NACK) mouseState = 0;

  return 0;
}

int sendToArchi(int row, int col , bool isBreak) {
  if (isBreak) {
    writeCodeWait(KUDA | row);
    waitForAck(BACK);

    // Send column
    writeCodeWait(KUDA | col);
    return waitForAckSet();

  } else {
    writeCodeWait(KDDA | row);
    waitForAck(BACK);

    // Send column
    writeCodeWait(KDDA | col);
    return waitForAckSet();
  }
  // Send row

}

int waitForAck(int expected) {

  int ackCode = readCodeBlocking(false);

  if (ackCode == expected) return 1;
  return -1;
}

int waitForAckSet() {
  
  int ackCode = readCodeBlocking(false);

  if (ackCode == MACK || ackCode == NACK || ackCode == SACK || ackCode == SMAK ) return ackCode;
  return -1;
}

uint8_t encode7bit(int8_t x) {
  uint8_t formatX = (uint8_t)(constrain(x, -64, 63) & 0x7F);
  return formatX;          // bit7 = 0, bit6 = sign
}


int readCodeNonBlocking(bool resetExpected) {
  int code;
  if(archiSerial.available()) {
    code = archiSerial.read();
  } else {
    return -2;
  }
  while (code == NBYTE) {
    
    if(archiSerial.available()) {
      code = archiSerial.read();
    } else {
      return -2;
    }
  }
  if (!resetExpected && code == HRST) {
    reset(false,false);
    return -1;
  }
  return code;
}

int readCodeBlocking(bool resetExpected) {
  int code;
  while(!archiSerial.available());
  code = archiSerial.read();
  while (code == NBYTE) {
    
    while(!archiSerial.available());
    code = archiSerial.read();
  }

  if (!resetExpected && code == HRST) {
    reset(false,false);
    return -1;
  }
  return code;
}

void writeCodeWait(int code) {
  delayMicroseconds(100);
  archiSerial.write(code);
}