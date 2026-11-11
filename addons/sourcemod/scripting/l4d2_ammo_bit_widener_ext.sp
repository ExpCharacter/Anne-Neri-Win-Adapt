/*
 * l4d2_ammo_bit_widener_ext
 * Copyright (C) 2026 ExpCharacter
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */
// Written with ChatGPT 6.1 sol high + deepseek flash.
//
// Widens m_iAmmo through the sendtable extension by Crimson-DawnLight:
//   https://github.com/Crimson-DawnLight/L4D2MutiMod (extensions/sendtable, v1.0.0)
// The extension is a separate binary; this plugin only calls its natives and
// does not embed or modify its code. Schema patching, buffer growth, framing
// and the CRC marker all live inside the extension.
// Requires SourceMod 1.12; the extension refuses SM 1.11 (IPlayerManager).
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sendtable>

#define PLUGIN_VERSION "1.1.0"

#define AMMO_CLASS        "CTerrorPlayer"
#define AMMO_PROP         "m_iAmmo"
#define AMMO_BITS_VANILLA 10
#define CLIP_CLASS        "CBaseCombatWeapon"
#define CLIP_PROP         "m_iClip1"
#define CLIP_BITS_VANILLA 8
#define BITS_WIDENED      16

bool g_WaitForMap;

public Plugin myinfo =
{
    name = "L4D2 Ammo Bit Widener (SendTable extension)",
    author = "ExpCharacter",
    description = "Widen m_iAmmo and m_iClip1 to 16 bits through sendtable.ext",
    version = PLUGIN_VERSION,
    url = "https://github.com/ExpCharacter/oh-my-l4d2-plugins"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int maxlength)
{
    g_WaitForMap = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    RegServerCmd("sm_ammo_bit_widener_ext_status", Cmd_Status);

    if (g_WaitForMap)
    {
        LogMessage("Late load: waiting for the next map initialization before widening ammo and clip");
        return;
    }

    ApplyBits();
}

public void OnMapInit(const char[] mapName)
{
    if (!g_WaitForMap)
        return;
    g_WaitForMap = false;
    ApplyBits();
}

void ApplyBits()
{
    int ammoBits = SendTable.GetBits(AMMO_CLASS, AMMO_PROP);
    if (ammoBits != BITS_WIDENED)
    {
        if (ammoBits == -1)
        {
            SetFailState("%s.%s not found; the send table layout changed",
                         AMMO_CLASS, AMMO_PROP);
        }
        if (ammoBits != AMMO_BITS_VANILLA)
        {
            SetFailState("%s.%s is %d bits, expected %d (vanilla) or %d (widened)",
                         AMMO_CLASS, AMMO_PROP, ammoBits, AMMO_BITS_VANILLA, BITS_WIDENED);
        }
        if (!SendTable.SetElementBits(AMMO_CLASS, AMMO_PROP, BITS_WIDENED, AMMO_BITS_VANILLA))
        {
            SetFailState("%s.%s widen failed: class/prop missing or expectedBits mismatch",
                         AMMO_CLASS, AMMO_PROP);
        }
    }

    int clipBits = SendTable.GetBits(CLIP_CLASS, CLIP_PROP);
    if (clipBits != BITS_WIDENED)
    {
        if (clipBits == -1)
        {
            LogError("%s.%s not found; the send table layout changed",
                     CLIP_CLASS, CLIP_PROP);
            return;
        }
        if (clipBits != CLIP_BITS_VANILLA)
        {
            LogError("%s.%s is %d bits, expected %d (vanilla) or %d (widened)",
                     CLIP_CLASS, CLIP_PROP, clipBits, CLIP_BITS_VANILLA, BITS_WIDENED);
            return;
        }
        if (!SendTable.SetBits(CLIP_CLASS, CLIP_PROP, BITS_WIDENED, CLIP_BITS_VANILLA))
        {
            LogError("%s.%s widen failed: class/prop missing or expectedBits mismatch",
                     CLIP_CLASS, CLIP_PROP);
        }
    }
}

public Action Cmd_Status(int args)
{
    PrintToServer("[ammo_bit_widener-ext] %s=%d %s=%d (expected %d); waiting_for_map=%d",
                  AMMO_PROP, SendTable.GetBits(AMMO_CLASS, AMMO_PROP),
                  CLIP_PROP, SendTable.GetBits(CLIP_CLASS, CLIP_PROP),
                  BITS_WIDENED, g_WaitForMap);
    return Plugin_Handled;
}
