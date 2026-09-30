#define CVS_CVAR_MAXLEN 64
#define CVARS_DEBUG		0

enum CVSEntry
{
	Handle:CVSE_cvar,
	String:CVSE_oldval[CVS_CVAR_MAXLEN],
	String:CVSE_newval[CVS_CVAR_MAXLEN]
}

static Handle:CvarSettingsArray;
static Handle:CVS_hPending;
static bool:bTrackingStarted;

// 把已经确认存在的 cvar 正式加入追踪表（登记 + 挂变更钩子）
static PushTrackedCvar(Handle:hCvar, const String:newval[])
{
	decl newEntry[CVSEntry];
	decl String:cvarBuffer[CVS_CVAR_MAXLEN];
	
	GetConVarString(hCvar, cvarBuffer, CVS_CVAR_MAXLEN);
	
	newEntry[CVSE_cvar] = hCvar;
	strcopy(newEntry[CVSE_oldval], CVS_CVAR_MAXLEN, cvarBuffer);
	strcopy(newEntry[CVSE_newval], CVS_CVAR_MAXLEN, newval);
	
	HookConVarChange(hCvar, CVS_ConVarChange);
	
	#if CVARS_DEBUG
		decl String:cvarName[CVS_CVAR_MAXLEN];
		GetConVarName(hCvar, cvarName, sizeof(cvarName));
		LogMessage("[Confogl] CvarSettings: cvar = %s, newval = %s, oldval = %s", cvarName, newval, cvarBuffer);
	#endif
	
	PushArrayArray(CvarSettingsArray, newEntry[0]);
}

// 重试挂起的登记项：宿主插件加载后其 cvar 才存在，届时补登记
static ResolvePendingCvars()
{
	new iSize = GetArraySize(CVS_hPending);
	if (iSize == 0) return;
	
	decl String:cvar[CVS_CVAR_MAXLEN], String:newval[CVS_CVAR_MAXLEN];
	
	// 倒序遍历，避免 RemoveFromArray 打乱尚未访问的项
	for (new i = iSize - 2; i >= 0; i -= 2)
	{
		GetArrayString(CVS_hPending, i, cvar, CVS_CVAR_MAXLEN);
		GetArrayString(CVS_hPending, i + 1, newval, CVS_CVAR_MAXLEN);
		
		new Handle:hCvar = FindConVar(cvar);
		if (hCvar == INVALID_HANDLE) continue;
		
		PushTrackedCvar(hCvar, newval);
		RemoveFromArray(CVS_hPending, i + 1);
		RemoveFromArray(CVS_hPending, i);
	}
}

CVS_OnModuleStart()
{
	CvarSettingsArray = CreateArray(_:CVSEntry);
	CVS_hPending = CreateArray(CVS_CVAR_MAXLEN);
	RegConsoleCmd("confogl_cvarsettings", CVS_CvarSettings_Cmd, "List all ConVars being enforced by Confogl");
	
	RegServerCmd("confogl_addcvar", CVS_AddCvar_Cmd, "Add a ConVar to be set by Confogl");
	RegServerCmd("confogl_setcvars", CVS_SetCvars_Cmd, "Starts enforcing ConVars that have been added.");
	RegServerCmd("confogl_resetcvars", CVS_ResetCvars_Cmd, "Resets enforced ConVars.  Cannot be used during a match!");
	
	
}

CVS_OnModuleEnd()
{
	ClearAllSettings();
}

CVS_OnConfigsExecuted()
{
	ResolvePendingCvars();

	if (bTrackingStarted) SetEnforcedCvars();
}

public Action:CVS_SetCvars_Cmd(args)
{
	if (IsPluginEnabled())
	{
		if (bTrackingStarted)
		{
			PrintToServer("Tracking has already been started");
			return;
		}
		#if CVARS_DEBUG
			LogMessage("[Confogl] CvarSettings: No longer accepting new ConVars");
		#endif
		ResolvePendingCvars();
		SetEnforcedCvars();
		bTrackingStarted = true;
	}
}

public Action:CVS_AddCvar_Cmd(args)
{
	if (args != 2)
	{
		PrintToServer("Usage: confogl_addcvar <cvar> <newValue>");
		if (IsDebugEnabled())
		{
			decl String:cmdbuf[MAX_NAME_LENGTH];
			GetCmdArgString(cmdbuf, sizeof(cmdbuf));
			LogError("[Confogl] Invalid Cvar Add: %s", cmdbuf);
		}
		return Plugin_Handled;
	}
	
	decl String:cvar[CVS_CVAR_MAXLEN], String:newval[CVS_CVAR_MAXLEN];
	GetCmdArg(1, cvar, sizeof(cvar));
	GetCmdArg(2, newval, sizeof(newval));
	
	AddCvar(cvar, newval);
	
	return Plugin_Handled;
}

public Action:CVS_ResetCvars_Cmd(args)
{
	if (IsPluginEnabled())
	{
		PrintToServer("Can't reset tracking in the middle of a match");
		return Plugin_Handled;
	}
	ClearAllSettings();
	PrintToServer("Server CVar Tracking Information Reset!");
	return Plugin_Handled;
}

public Action:CVS_CvarSettings_Cmd(client, args)
{
	if (!IsPluginEnabled()) return Plugin_Handled;
	
	if (!bTrackingStarted)
	{
		return Plugin_Handled;
	}
	
	new cvscount = GetArraySize(CvarSettingsArray);
	decl cvsetting[CVSEntry];
	decl String:buffer[CVS_CVAR_MAXLEN], String:name[CVS_CVAR_MAXLEN];
	
	
	GetCmdArg(1, buffer, sizeof(buffer));
	new offset = StringToInt(buffer);
	
	if (offset < 0 || offset > cvscount) return Plugin_Handled;
	
	new temp = cvscount;
	if (offset + 20 < cvscount) temp = offset + 20;
	
	for (new i = offset; i < temp && i < cvscount; i++)
	{
		GetArrayArray(CvarSettingsArray, i, cvsetting[0]);
		GetConVarString(cvsetting[CVSE_cvar], buffer, sizeof(buffer));
		GetConVarName(cvsetting[CVSE_cvar], name, sizeof(name));
	}
	return Plugin_Handled;
}


static ClearAllSettings()
{
	bTrackingStarted = false;
	new cvsetting[CVSEntry];
	for (new i; i < GetArraySize(CvarSettingsArray); i++)
	{
		GetArrayArray(CvarSettingsArray, i, cvsetting[0]);
		
		UnhookConVarChange(cvsetting[CVSE_cvar], CVS_ConVarChange);
		SetConVarString(cvsetting[CVSE_cvar], cvsetting[CVSE_oldval]);
	}
	ClearArray(CvarSettingsArray);
	ClearArray(CVS_hPending);
}

static SetEnforcedCvars()
{
	new cvsetting[CVSEntry];
	for (new i; i < GetArraySize(CvarSettingsArray); i++)
	{
		GetArrayArray(CvarSettingsArray, i, cvsetting[0]);
		#if CVARS_DEBUG
			decl String:debug_buffer[CVS_CVAR_MAXLEN];
			GetConVarName(cvsetting[CVSE_cvar], debug_buffer, sizeof(debug_buffer));
			LogMessage("cvar = %s, newval = %s", debug_buffer, cvsetting[CVSE_newval]);
		#endif
		SetConVarString(cvsetting[CVSE_cvar], cvsetting[CVSE_newval]);
	}
}

static AddCvar(const String:cvar[], const String:newval[])
{
	if (strlen(cvar) >= CVS_CVAR_MAXLEN)
	{
		LogError("[Confogl] CvarSettings: CVar Specified (%s) is longer than max cvar/value length (%d)", cvar, CVS_CVAR_MAXLEN);
		return;
	}
	if (strlen(newval) >= CVS_CVAR_MAXLEN)
	{
		LogError("[Confogl] CvarSettings: New Value Specified (%s) is longer than max cvar/value length (%d)", newval, CVS_CVAR_MAXLEN);
		return;
	}
	
	decl newEntry[CVSEntry];
	decl String:cvarBuffer[CVS_CVAR_MAXLEN];
	
	// 重复检查必须排在 bTrackingStarted 分支之前：confogl.cfg 每次模式加载会重放多次，
	// 同样的 confogl_addcvar 会再次走到这里。
	for (new i; i < GetArraySize(CvarSettingsArray); i++)
	{
		GetArrayArray(CvarSettingsArray, i, newEntry[0]);
		GetConVarName(newEntry[CVSE_cvar], cvarBuffer, CVS_CVAR_MAXLEN);
		if (StrEqual(cvar, cvarBuffer, false))
		{
			LogError("[Confogl] CvarSettings: Attempt to track ConVar %s, which is already being tracked.", cvar);
			return;
		}
	}
	
	for (new i; i < GetArraySize(CVS_hPending); i += 2)
	{
		GetArrayString(CVS_hPending, i, cvarBuffer, CVS_CVAR_MAXLEN);
		if (StrEqual(cvar, cvarBuffer, false))
		{
			LogError("[Confogl] CvarSettings: Attempt to track ConVar %s, which is already pending late-bind.", cvar);
			return;
		}
	}
	
	if (bTrackingStarted)
	{
		// Windows 特有：confogl.cfg（内含 confogl_setcvars）会在 confogl_plugins.cfg 执行到
		// 一半时提前跑完，其后的 vote/*.cfg 里的 confogl_addcvar 走到这里时 tracking 已启动。
		// 上游写法在此静默丢弃，那些 cvar 会永远停在默认值；Windows 上改为挂起，
		// 由 CVS_OnConfigsExecuted() 的 ResolvePendingCvars() 补登记并强制。
		PushArrayString(CVS_hPending, cvar);
		PushArrayString(CVS_hPending, newval);
		
		#if CVARS_DEBUG
			LogMessage("[Confogl] CvarSettings: Pending late-bind (tracking already started) for cvar = %s, newval = %s", cvar, newval);
		#endif
		return;
	}
	
	new Handle:newCvar = FindConVar(cvar);
	
	if (newCvar == INVALID_HANDLE)
	{
		// 模式 cfg 里 confogl_addcvar 早于插件加载，宿主插件的 cvar 此刻还不存在：
		// 不再报错丢弃，改为挂起，等 CVS_OnConfigsExecuted 时宿主已加载再补登记。
		PushArrayString(CVS_hPending, cvar);
		PushArrayString(CVS_hPending, newval);
		
		#if CVARS_DEBUG
			LogMessage("[Confogl] CvarSettings: Pending late-bind for cvar = %s, newval = %s", cvar, newval);
		#endif
		return;
	}
	
	PushTrackedCvar(newCvar, newval);
}

public CVS_ConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (bTrackingStarted)
	{
		decl String:name[CVS_CVAR_MAXLEN];
		GetConVarName(convar, name, sizeof(name));
	}
}
