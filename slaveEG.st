// Алгоблок поддерживает 1, 2, 3, 4, 5, 6, 15 и 16 команды протокола modbus, также поддерживается пользовательская функция с номером 20. 
// В тело запроса этой пользовательской функции вносятся содержимое буфера пользовательских данных pData . 0-м элементом буфера pData должен быть актуальный номер пользовательской функции, причем этот номер не обязан быть равен 20.
FUNCTION_BLOCK ModbusRtuRequest

VAR_INPUT
	xExecute : BOOL;             //Сигнал на включение алгоблока
	tTimeout : TIME;             // Максимальное время ожидания ответа от подчиненного устройства
	hCom : MZTA.COM.CAA.HANDLE;       // Дескриптор COM порта, по которому будет производиться передача данных
	usiDeviceAddr : USINT;       // Адрес устройства, которому адресован запрос
	eFunc : MZTA.MODBUS_FUNC;         // Используемая modbus функция
	uiDataAddr : UINT;           // Адрес первого регистра/бита в запросе
	uiDataCount : UINT;          // Количество запрашиваемых регистров/битов в запроса
	usiByteCount : USINT;        // Ожидаемое количество байт данных в ответе или 0
	pData : MZTA.CAA.PVOID;           // Указатель на буфер с пользовательскими данными
	szSize :MZTA. COM.CAA.SIZE;       // Размер буфера с пользовательскими данными
END_VAR

VAR_OUTPUT
	xDone : BOOL;                // Блок успешно завершил свою работу
	xBusy : BOOL;                // В настоящее время блок занят выполнением своего функционала
	xError : BOOL;               // Обнаружена ошибка
	eError : MZTA.ERRORS;             // Тип обнаруженной ошибки
END_VAR

VAR
	eState : MZTA.MB_MASTER_STATE;   // Текущее состояние блока	
	fb_TON : TON;               // Таймер задержки включения
	pWorkBuff : MZTA.CAA.PVOID;      // Указатель на глобальный буфер для хранения данных
	uiReadCount : UINT;         // Количество прочитаных байт за несколько циклов
	uiExpectReadCount : UINT;   // Ожидаемое количество байт в соответствии с отправленым запросом
	pTmpBuff : POINTER TO ARRAY[0..MZTA.gModbusVar.G_MB_WORK_BUFF_SIZE-1] OF BYTE;
END_VAR
VAR_TEMP
	i : UINT;
	uiMsgSize : UINT;
	eResult : MZTA.ERRORS;
	usiByteCount1 : USINT;
	res: MZTA.SysCom.RTS_IEC_RESULT;
	udiStepReadCount : UDINT;
	uiStepBufferSize : UINT;
END_VAR
IF xExecute THEN
	CASE eState OF 
		// =============================================
		// Проверка устройства
		MZTA.MB_MASTER_STATE.DEVICE_CHECK:
			eResult := MZTA.DeviceCheck();
			IF eResult <> MZTA.ERRORS.OK THEN				
				eError := eResult;
				xError := TRUE;	
			END_IF
			
			IF szSize > MZTA.gModbusVar.G_MB_DATA_BUFF_SIZE  THEN
				eError := MZTA.ERRORS.ARG_INVALID;
				xError := TRUE;				
			END_IF
			
			IF xError = FALSE THEN
				eState := MZTA.MB_MASTER_STATE.WRITE;
			END_IF
			
		// =============================================
		// Отправка сообщения
		MZTA.MB_MASTER_STATE.WRITE:
			FOR i:=0 TO MZTA.gModbusVar.G_MB_STRUCT_COUNT BY 1 DO
				IF MZTA.gModbusVar.g_aModbusStruct[i].hCom = hCom THEN
					pWorkBuff := MZTA.gModbusVar.g_aModbusStruct[i].pBuff;
					pTmpBuff := MZTA.gModbusVar.g_aModbusStruct[i].pBuff;
					EXIT;
				END_IF
			END_FOR
			
			eResult := MZTA.ModbusRtuCreatReq(pWorkBuff, ADR(uiMsgSize), usiDeviceAddr, eFunc, uiDataAddr, uiDataCount, pData, szSize);
			IF (eResult <> MZTA.ERRORS.OK) THEN
				xError := TRUE;
				eError := eResult;
				RETURN;
			END_IF
		
			// Отправка сообщения
			MZTA.SysComPurge(hCom);
			MZTA.SysComWrite(hCom, pWorkBuff, uiMsgSize, 0, ADR(res));
			
			IF res = 0 THEN
				fb_TON(IN := FALSE);
				fb_TON(IN := TRUE, PT := tTimeout);
				uiReadCount := 0;
				IF usiByteCount = 0 THEN
					usiByteCount1 := MZTA.ModbusCalcDataCount(eFunc, uiDataCount);
				ELSE
					usiByteCount1 := usiByteCount;
				END_IF
				uiExpectReadCount := MZTA.ModBusCalcExpectCount(eFunc, usiByteCount1, 0);
				eState := MZTA.MB_MASTER_STATE.WAIT;
			ELSE
				xError := TRUE;
				eError := MZTA.Errors.FAILURE;
				eState := MZTA.MB_MASTER_STATE.END;
				RETURN;
			END_IF
			xBusy := TRUE;
				
	    // =============================================
		// Ожидание ответа от устройства
		MZTA.MB_MASTER_STATE.WAIT:
			// Чтение данных из порта
			uiStepBufferSize := MZTA.gModbusVar.G_MB_WORK_BUFF_SIZE - uiReadCount;
			udiStepReadCount := MZTA.SysComRead(hCom, ADR(pTmpBuff^[uiReadCount]), uiStepBufferSize, 0, ADR(res));
			IF res = 0 THEN
				IF udiStepReadCount > 0 THEN 
					uiReadCount := uiReadCount + ANY_TO_UINT(udiStepReadCount);
					// Проверка конца сообщения
					IF uiReadCount > 0 THEN
						IF uiReadCount >= uiExpectReadCount THEN
							eState := MZTA.MB_MASTER_STATE.READ;
							RETURN;
						END_IF
						IF uiReadCount = 5 AND pTmpBuff^[1] >= 128 THEN
							eState := MZTA.MB_MASTER_STATE.READ;
							RETURN;
						END_IF					
					END_IF
				ELSE
					// Проверка таймаута
					fb_TON(IN:=TRUE, PT:= tTimeout);
					IF fb_TON.Q THEN
						xError := TRUE;
						eError := MZTA.ERRORS.TIMEOUT;
						eState := MZTA.MB_MASTER_STATE.END;
					END_IF					
				END_IF
			ELSE
				eState := MZTA.MB_MASTER_STATE.END;
				xError := TRUE;
				eError := MZTA.Errors.FAILURE;
				RETURN;
			END_IF

		// =============================================
		// Чтение ответа от устройства
		MZTA.MB_MASTER_STATE.READ:	
			eResult := MZTA.ModbusRtuParsAns(pData, szSize, usiDeviceAddr, eFunc, uiDataAddr, uiDataCount, pWorkBuff, uiReadCount);
			
			IF (eResult <> MZTA.ERRORS.OK) THEN
				xError := TRUE;
				eError := eResult;
				eState := MZTA.MB_MASTER_STATE.END;
				RETURN;
			END_IF	

			xDone := TRUE;
			xError := FALSE;
			eState := MZTA.MB_MASTER_STATE.END;
		
		// =============================================
		// Окончание цикла приемо/передачи
		MZTA.MB_MASTER_STATE.END:
			xBusy := FALSE;
			//IF NOT xError THEN
			//	xDone := TRUE;
			//END_IF
	END_CASE 
ELSE
	xBusy := FALSE;
	xError := FALSE;
	eError := MZTA.ERRORS.OK;
	xDone := FALSE;
	eState := MZTA.MB_MASTER_STATE.WRITE;
END_IF
