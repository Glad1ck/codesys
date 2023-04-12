PROGRAM PLC_PRG
VAR
    redLight, yellowLight, greenLight: BOOL;
    state: (RED, RED_YELLOW, GREEN, YELLOW);
    timer: TON;
    duration: TIME;

    // Modbus TCP Slave переменные
    ModbusSlave: MZTA.ModbusTCPSlave;
    outputCoils: ARRAY[0..2] OF BOOL;
    inputContacts: ARRAY[0..2] OF BOOL;
    inputRegisters: ARRAY[0..0] OF WORD;
    outputHoldingRegisters: ARRAY[0..0] OF WORD;
END_VAR

// Установка времени переключения для каждого состояния
CASE state OF
    RED:
        duration := T#10s;
        redLight := TRUE;
        yellowLight := FALSE;
        greenLight := FALSE;
    RED_YELLOW:
        duration := T#2s;
        redLight := TRUE;
        yellowLight := TRUE;
        greenLight := FALSE;
    GREEN:
        duration := T#10s;
        redLight := FALSE;
        yellowLight := FALSE;
        greenLight := TRUE;
    YELLOW:
        duration := T#3s;
        redLight := FALSE;
        yellowLight := TRUE;
        greenLight := FALSE;
END_CASE;

timer(IN:= NOT timer.Q, PT:= duration);

IF timer.Q THEN
    CASE state OF
        RED:
            state := RED_YELLOW;
        RED_YELLOW:
            state := GREEN;
        GREEN:
            state := YELLOW;
        YELLOW:
            state := RED;
    END_CASE;
END_IF;

// Инициализация и обновление Modbus TCP Slave
modbusSlave(
    xEnable := TRUE,
    usiUnitId := 1,
    uiPort := 502,
    pDataOutputCoils := ADR(outputCoils),
    szSizeOutputCoils := SIZEOF(outputCoils),
    pDataInputContacts := ADR(inputContacts),
    szSizeInputContacts := SIZEOF(inputContacts),
    pDataInputRegisters := ADR(inputRegisters),
    szSizeInputRegisters := SIZEOF(inputRegisters),
    pDataOutputHoldingRegisters := ADR(outputHoldingRegisters),
    szSizeOutputHoldingRegisters := SIZEOF(outputHoldingRegisters)
);

// Обновление данных Modbus
outputCoils[0] := redLight;
outputCoils[1] := yellowLight;
outputCoils[2] := greenLight;

inputContacts[0] := redLight;
inputContacts[1] := yellowLight;
inputContacts[2] := greenLight;
;