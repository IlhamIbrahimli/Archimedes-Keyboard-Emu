#include <LinkedList.h>
#include <PS2Keyboard.h>
#include <PS2MouseHandler.h>
#define MDATA 4
#define MCLK 5
#define KDAT 6
#define KCLK 7


//Define archimedes codes
#define HRST 0xFF
#define RAK1 0xFE
#define RAK2 0xFD
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

const PROGMEM ArchiKeymap_t keymap_Archi = {{0, 0x00, 0, 0x00, 0x00, 0x00, 0x00, 0x00,
	0, 0x00, 0x00, 0x00, 0x00, 0x02, 0x01, 0,
	0, 0x05 /*Lalt*/, 0x04 /*Lshift*/, 0, 0x03 /*Lctrl*/, 0x02, 0x01, 0,
	0, 0, 0x04, 0x03, 0x03, 0x02, 0x01, 0,
	0, 0x05, 0x04, 0x03, 0x02, 0x01, 0x01, 0,
	0, 0x05, 0x05, 0x03, 0x02, 0x02, 0x01, 0,
	0, 0x05, 0x05, 0x04, 0x04, 0x02, 0x01, 0,
	0, 0, 0x05, 0x04, 0x02, 0x01, 0x01, 0,
	0, 0x05, 0x05, 0x02, 0x02, 0x01, 0x01, 0,
	0, 0x05, 0x05, 0x04, 0x04, 0x03, 0x01, 0,
	0, 0, 0x04, 0, 0x03, 0x01, 0, 0,
	0x05 /*CapsLock*/, 0x05 /*Rshift*/, 0x04 /*Enter*/, 0x03, 0, 0x02, 0, 0,
	0, '0x03', 0, 0, 0, 0, 0x01, 0,
	0, 0x05, 0, 0x04, 0x03, 0, 0, 0,
	0x06, 0x06, 0x05, 0x04, 0x04, 0x03, 0x00, 0x02 /*NumLock*/,
	0x00, 0x04, 0x05, 0x03, 0x02, 0x03, 0x00, 0,
	0, 0, 0, 0x00 },

  {0, 0x09, 0, 0x05, 0x03, 0x01, 0x02, 0x0C,
	0, 0x0A, 0x08, 0x06, 0x04, 0x06, 0x00, 0,
	0, 0x0E /*Lalt*/, 0x0C /*Lshift*/, 0, 0x0B /*Lctrl*/, 0x07, 0x01, 0,
	0, 0, 0x0E, 0x0D, 0x0C, 0x08, 0x02, 0,
	0, 0x00, 0x0F, 0x0E, 0x09, 0x04, 0x03, 0,
	0, 0x0F, 0x01, 0x0F, 0x0B, 0x0A, 0x05, 0,
	0, 0x03, 0x02, 0x01, 0x00, 0x0C, 0x06, 0,
	0, 0, 0x04, 0x02, 0x0D, 0x07, 0x08, 0,
	0, 0x05, 0x03, 0x0E, 0x0F, 0x0A, 0x09, 0,
	0, 0x06, 0x07, 0x04, 0x05, 0x00, 0x0A, 0,
	0, 0, 0x06, 0, 0x01, 0x0C, 0, 0,
	0x0D /*CapsLock*/, 0x08 /*Rshift*/, 0x07 /*Enter*/, 0x02, 0, 0x05, 0, 0,
	0, 0x03, 0, 0, 0, 0, 0x0E, 0,
	0, 0x0A, 0, 0x08, 0x07, 0, 0, 0,
	0x05, 0x06, 0x0B, 0x09, 0x0A, 0x08, 0x00, 0x02 /*NumLock*/,
	0x0B, 0x0B, 0x0C, 0x0A, 0x04, 0x09, 0x0E, 0,
	0, 0, 0, 0x07}};

   
int mouseState = 0;
int ackCode = 0x00;
//0 - NACK - Only RQMP, No Keyboard.
//1 - SACK - Only RQMP, Yes Keyboard
//2 - MACK - Only non zero X OR Y, No Keyboard
//3 - SMAK - Both MACK AND SACK
const PROGMEM int ArchiExtended[14][3] = {{0xE014, 0x06,0x01},{0xE011,0x06, 0x00}, {0xE070, 0x01, 0x0F}, {0xE06C, 0x02, 0x00}, {0xE07D,0x02, 0x01}, {0xE071, 0x03, 0x04}, {0xE069,0x03,0x05}, 
{0xE07A, 0x03, 0x06}, {0xE075, 0x05,0x09}, {0xE06B, 0x06, 0x02}, {0xE072, 0x06, 0x03}, {0xE074, 0x06, 0x04}, {0xE04A, 0x02, 0x03}, {0xE05A, 0x06, 0x07}};

/*Quick note on Key changes
Pressing end will press copy. To press end actually press Shift+End
Hashtag key gives hastag
To get tilda (~) press Shift + ` (The one under escape)*/

void setup() {
  // put your setup code here, to run once:
  
  Serial.begin(9600);
  Serial.println(HRST);
  //int abc = mouse.initialise();
  //Serial.println(0xFE);
  keyboard.begin(KDAT, KCLK);
  Serial.println(0xFE);
  int a = reset(true);
  Serial.println(a);
}


int reset(bool selfInit) {
  // Keyboard sends HRST and waits for ARM reply
  
  int code;
  Serial.println(HRST);
  if (selfInit) {
    while(!Serial.available());
    code = Serial.read();
    if (code == HRST) {
      
      Serial.println(HRST);
    } else {
      return -1;
    }
  }
  while(!Serial.available());
  code = Serial.read();
  if (code == RAK1) {

    Serial.println(RAK1);
  } else {
    return -1;
  }
  while(!Serial.available());
  code = Serial.read();
  if (code == RAK2) {

    Serial.println(RAK2);
  } else {
    return -1;
  }
  while(!Serial.available());
  code = Serial.read();
  if (code == SMAK) {
    mouseState = 3;
  }else if (code == SACK) {
    mouseState = 1;
  }else if (code == MACK) {
    mouseState = 2;
  }else if (code == NACK) {
    mouseState = 0;
  } else {
    return -1;
  }
  return 0;
}

int SendKeys() {
  ackCode = 0x00;
  int tempCode = NULL;
  int scanval;
  int scratchScan;
  bool extended = false;
  bool breakCode = false;
  if(keyboard.available()) {
    scanval = keyboard.readScanCode();
    bool inArray = false;
    for (int q = 0; q < heldKeys.size();q++) {
      if (heldKeys.get(q) == scanval) {
        inArray = true;
        break;
      }
    }
    while(keyboard.available() && inArray) {
      scanval = keyboard.readScanCode();
      inArray = false;
      for (int w = 0; w < heldKeys.size();w++) {
        if (heldKeys.get(w) == scanval) {
          inArray = true;
          break;
        }
      }
    }
  }else {
    return NULL;
  }
  
  bool makePrnt = false;
  bool breakPrnt = false;
  if (scanval == 0xE0) {
    extended = true;
    while(!keyboard.available());
    scanval = keyboard.readScanCode(); 
    if (scanval == 0x12) {
      makePrnt = true;
      // Clear rest of buffer
      scratchScan = keyboard.readScanCode(); // Read E0
      scratchScan = keyboard.readScanCode(); // Read 7C
    }
  } 
  if (scanval == 0xF0) {
    breakCode = true;
    while(!keyboard.available());
    scanval = keyboard.readScanCode();
    if(extended && scanval == 0x7C) {
      breakPrnt = true;
      // Clear rest of buffer
      scratchScan = keyboard.readScanCode(); // Read E0
      scratchScan = keyboard.readScanCode(); // Read F0
      scratchScan = keyboard.readScanCode(); // Read 12
    }
  } 
  int fullCode;
  if (extended) {
    fullCode = (0xE0 << 8) | scanval;
  }else {
    fullCode = scanval;
  }
  
  if (fullCode == 0xE07C) { // Make sure break and make of PrtScr stay the same in list.
    fullCode = 0xE012;
  }


  bool needToSend = true;
  int rowToSend = NULL;
  int colToSend = NULL;
  if (breakCode) {
    for (int e = 0; e < heldKeys.size();e++) {
        if (heldKeys.get(e) == fullCode) {
        heldKeys.remove(e);
        break;
      }

    }
    if (extended) {
      if (breakPrnt) {
        rowToSend = 0x00;
        colToSend = 0x0D;
      }else {
        for (int r = 0; r < 13; r++) {
          if (fullCode == ArchiExtended[r][0]) {
            rowToSend = ArchiExtended[r][1];
            colToSend = ArchiExtended[r][2];
          }
        }
      }
      Serial.println((KUDA | rowToSend));
      while(!Serial.available());
      ackCode = Serial.read();
      while (ackCode != BACK) {
        if (ackCode == HRST) {
          reset(false);
          return NULL;
        }else if (ackCode == RQID) {
          tempCode = RQID;
        }else if (ackCode == RQMP) {
          tempCode = RQMP;
        }
        while(!Serial.available());
        ackCode = Serial.read();
      }
      Serial.println((KUDA | colToSend));
      while (ackCode != NACK || ackCode != MACK || ackCode != SACK || ackCode != SMAK) {
        if (ackCode == HRST) {
          reset(false);
          return NULL;
        }else if (ackCode == RQID) {
          tempCode = RQID;
        }else if (ackCode == RQMP) {
          tempCode = RQMP;
        }
        while(!Serial.available());
        ackCode = Serial.read();
      }
    }else {
      Serial.println((KUDA | keymap_Archi.rows[scanval]));
      while(!Serial.available());
      ackCode = Serial.read();
      while (ackCode != BACK) {
        if (ackCode == HRST) {
          reset(false);
          return NULL;
        }else if (ackCode == RQID) {
          tempCode = RQID;
        }else if (ackCode == RQMP) {
          tempCode = RQMP;
        }
        while(!Serial.available());
        ackCode = Serial.read();
      }
      Serial.println((KUDA | keymap_Archi.columns[scanval]));
      while (ackCode != NACK || ackCode != MACK || ackCode != SACK || ackCode != SMAK) {
        if (ackCode == HRST) {
          reset(false);
          return NULL;
        }else if (ackCode == RQID) {
          tempCode = RQID;
        }else if (ackCode == RQMP) {
          tempCode = RQMP;
        }
        while(!Serial.available());
        ackCode = Serial.read();
      }
    
    }

  }else { 
    for (int t = 0; t < heldKeys.size();t++) {
      if (heldKeys.get(t) == fullCode) {
        needToSend = false;
        break;
      }
    }
    if (needToSend) {
      if (extended) {
        if (makePrnt) {
        rowToSend = 0x00;
        colToSend = 0x0D;
        }else {
          for (int y = 0; y < 13; y++) {
            if (fullCode == ArchiExtended[y][0]) {
              rowToSend = ArchiExtended[y][1];
              colToSend = ArchiExtended[y][2];
            }
          }
        }
        Serial.println((KDDA | rowToSend));
        while(!Serial.available());
        ackCode = Serial.read();
        while (ackCode != BACK) {
          if (ackCode == HRST) {
            reset(false);
            return NULL;
          }else if (ackCode == RQID) {
            tempCode = RQID;
          }else if (ackCode == RQMP) {
            tempCode = RQMP;
          }
          while(!Serial.available());
          ackCode = Serial.read();
        }
        Serial.println((KDDA | colToSend));
        while (ackCode != NACK || ackCode != MACK || ackCode != SACK || ackCode != SMAK) {
          if (ackCode == HRST) {
            reset(false);
            return NULL;
          }else if (ackCode == RQID) {
            tempCode = RQID;
          }else if (ackCode == RQMP) {
            tempCode = RQMP;
          }
          while(!Serial.available());
          ackCode = Serial.read();
        }
      }else {
        Serial.println((KDDA | keymap_Archi.rows[scanval]));
        while(!Serial.available());
        ackCode = Serial.read();
        while (ackCode != BACK) {
          if (ackCode == HRST) {
            reset(false);
            return NULL;
          }else if (ackCode == RQID) {
            tempCode = RQID;
          }else if (ackCode == RQMP) {
            tempCode = RQMP;
          }
          while(!Serial.available());
          ackCode = Serial.read();
        }
        Serial.println((KDDA | keymap_Archi.columns[scanval]));
        while (ackCode != NACK || ackCode != MACK || ackCode != SACK || ackCode != SMAK) {
          if (ackCode == HRST) {
            reset(false);
            return NULL;
          }else if (ackCode == RQID) {
            tempCode = RQID;
          }else if (ackCode == RQMP) {
            tempCode = RQMP;
          }
          while(!Serial.available());
          ackCode = Serial.read();
        }

      }
    }
  }

  if (ackCode == SMAK) {
    mouseState = 3;
  }else if (ackCode == SACK) {
    mouseState = 1;
  }else if (ackCode == MACK) {
    mouseState = 2;
  }else if (ackCode == NACK) {
    mouseState = 0;
  }
  return tempCode;
}
int SendMBI(int button,bool Down) {
  int tempCode = NULL;
  ackCode = NULL;
  int codeToSend = (Down == true) ? KDDA : KUDA;
  int rowToSend = 0x07;
  int colToSend = button;
  Serial.println((codeToSend | rowToSend));
  while(!Serial.available());
  ackCode = Serial.read();
  while (ackCode != BACK) {
    if (ackCode == HRST) {
      reset(false);
      return NULL;
    }else if (ackCode == RQID) {
      tempCode = RQID;
    }else if (ackCode == RQMP) {
      tempCode = RQMP;
    }
    while(!Serial.available());
    ackCode = Serial.read();
  }
  Serial.println((codeToSend | colToSend));
  while (ackCode != NACK || ackCode != MACK || ackCode != SACK || ackCode != SMAK) {
    if (ackCode == HRST) {
      reset(false);
      return NULL;
    }else if (ackCode == RQID) {
      tempCode = RQID;
    }else if (ackCode == RQMP) {
      tempCode = RQMP;
    }
    while(!Serial.available());
    ackCode = Serial.read();
  }
      

  if (ackCode == SMAK) {
    mouseState = 3;
  }else if (ackCode == SACK) {
    mouseState = 1;
  }else if (ackCode == MACK) {
    mouseState = 2;
  }else if (ackCode == NACK) {
    mouseState = 0;
  }
  return tempCode;
}


int mousePos(int x,int y) {
  ackCode = NULL;
  int tempCode = NULL;
  uint8_t clampedX = constrain(x,-64,63);
  uint8_t formatX = (clampedX & 0x3f) | ((clampedX >> 1) & 0x40);
  Serial.println(formatX);
  while(!Serial.available());
  ackCode = Serial.read();
  while (ackCode != BACK) {
    if (ackCode == HRST) {
      reset(false);
      return NULL;
    }else if (ackCode == RQID) {
      tempCode = RQID;
    }else if (ackCode == RQMP) {
      tempCode = RQMP;
    }
    while(!Serial.available());
    ackCode = Serial.read();
  }
  uint8_t clampedY = constrain(y,-64,63);
  uint8_t formatY = (clampedY & 0x3f) | ((clampedY >> 1) & 0x40);
  Serial.println(formatY);
  while (ackCode != NACK || ackCode != MACK || ackCode != SACK || ackCode != SMAK) {
    if (ackCode == HRST) {
      reset(false);
      return NULL;
    }else if (ackCode == RQID) {
      tempCode = RQID;
    }else if (ackCode == RQMP) {
      tempCode = RQMP;
    }
    while(!Serial.available());
    ackCode = Serial.read();
  }
  if (ackCode == SMAK) {
    mouseState = 3;
  }else if (ackCode == SACK) {
    mouseState = 1;
  }else if (ackCode == MACK) {
    mouseState = 2;
  }else if (ackCode == NACK) {
    mouseState = 0;
  }
  return tempCode;
}



void loop() {
  // put your main code here, to run repeatedly:
  int heldCode = NULL;
  mouse.get_data();
  int16_t x = 0;
  int16_t y = 0;
  if (mouseState == 1 || mouseState == 3) {
    heldCode = SendKeys();
    //Send keyboard info & Mouse button info
    //for loop
    while (heldCode != NULL) {
      if (heldCode == RQMP) {
        x = mouse.x_movement();
        y = mouse.y_movement();
        heldCode = mousePos(x,y);
      } else if (heldCode == RQID){
        Serial.println(KBID);
        heldCode = NULL;
      }
    }
  }
  int ButtonCount = 0;
  bool tempPress = false;
  while((mouseState == 1 || mouseState == 3) && ButtonCount < 3) {
    tempPress = mouse.button(ButtonCount);
    if (tempPress == true && PrevMB[ButtonCount] == false) {
      heldCode = SendMBI(ButtonCount, true);
    } else if(tempPress == false && PrevMB[ButtonCount] == true) {
      heldCode = SendMBI(ButtonCount, false);
    }
    PrevMB[ButtonCount] = tempPress;
    ButtonCount++;
    while (heldCode != NULL) {
      if (heldCode == RQMP) {
        x = mouse.x_movement();
        y = mouse.y_movement();
        heldCode = mousePos(x,y);
      } else if (heldCode == RQID){
        Serial.println(KBID);
        heldCode = NULL;
      }
    }
  }
  while (heldCode != NULL) {
    if (heldCode == RQMP) {
      x = mouse.x_movement();
      y = mouse.y_movement();
      heldCode = mousePos(x,y);
    } else if (heldCode == RQID){
      Serial.println(KBID);
      heldCode = NULL;
    }
  }

  if (mouseState == 2 || mouseState == 3) {
    x = mouse.x_movement();
    y = mouse.y_movement();
    if (x != 0 || y != 0) {
      heldCode = mousePos(x,y);
    }
  }
  while (heldCode != NULL) {
    if (heldCode == RQMP) {
      heldCode = mousePos(x,y);
    } else if (heldCode == RQID){
      Serial.println(KBID);
      heldCode = NULL;
    }
  }
}