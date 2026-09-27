::Sakiko_InspectState <- {};
::Sakiko_ClearInspect <- function(clientIndex) {
    if (clientIndex in ::Sakiko_InspectState) { ::Sakiko_InspectState[clientIndex].active = false; }
    local p = PlayerInstanceFromIndex(clientIndex); if(!p) return;
    local vm = NetProps.GetPropEntity(p, "m_hViewModel");
    local aw = p.GetActiveWeapon();
    if (clientIndex in ::Sakiko_InspectState) {
        local state = ::Sakiko_InspectState[clientIndex];
        if (vm && NetProps.GetPropInt(vm, "m_nLayerSequence") == state.last_ani && state.last_ani != -1) {
            NetProps.SetPropInt(vm, "m_nLayerSequence", -1);
            NetProps.SetPropInt(vm, "m_nLayer", 0);
        }
    }
    if(aw && NetProps.GetPropInt(aw, "m_helpingHandState") == 6) NetProps.SetPropInt(aw, "m_helpingHandState", 0);
};
::Sakiko_PlayInspectLoop <- function(clientIndex) {
    if (!(clientIndex in ::Sakiko_InspectState)) return;
    local state = ::Sakiko_InspectState[clientIndex];
    if (!state.active) return;
    local p = PlayerInstanceFromIndex(clientIndex); if(!p) return;
    local aw = p.GetActiveWeapon();
    if(aw != state.weapon) { ::Sakiko_ClearInspect(clientIndex); return; }
    local vm = NetProps.GetPropEntity(p, "m_hViewModel"); if(!vm) return;
    if (state.loop != -1) {
        NetProps.SetPropInt(vm, "m_nLayerSequence", state.loop);
        NetProps.SetPropInt(vm, "m_nLayer", 0);
        NetProps.SetPropFloat(vm, "m_flLayerStartTime", Time() + 0.1);
        state.last_ani = state.loop;
    } else {
        ::Sakiko_ClearInspect(clientIndex);
    }
};
::Sakiko_ToggleInspect <- function(clientIndex, fallbackSeq, maxSeq) {
    local p = PlayerInstanceFromIndex(clientIndex); if(!p) return;
    local vm = NetProps.GetPropEntity(p, "m_hViewModel"); if(!vm) return;
    local aw = p.GetActiveWeapon();
    if (!(clientIndex in ::Sakiko_InspectState)) {
        ::Sakiko_InspectState[clientIndex] <- { active=false, ext=-1, loop=-1, ret=-1, last_ani=-1, weapon=null };
    }
    local state = ::Sakiko_InspectState[clientIndex];
    local current_seq = NetProps.GetPropInt(vm, "m_nLayerSequence");
    if (state.active && current_seq != state.last_ani) {
        state.active = false;
    }
    if (state.active) {
        if (state.ret != -1) {
            NetProps.SetPropInt(vm, "m_nLayerSequence", state.ret);
            NetProps.SetPropInt(vm, "m_nLayer", 0);
            NetProps.SetPropFloat(vm, "m_flLayerStartTime", Time());
            state.last_ani = state.ret;
            local dur = vm.GetSequenceDuration(state.ret);
            DoEntFire("sakiko_inspect_script", "RunScriptCode", "::Sakiko_ClearInspect(" + clientIndex + ")", dur, null, null);
            state.active = false;
        } else {
            ::Sakiko_ClearInspect(clientIndex);
        }
        return;
    }
    if (!("Sakiko_AnimCache" in ::Sakiko_InspectState)) ::Sakiko_InspectState.Sakiko_AnimCache <- {};
    local mdl = vm.GetModelName();
    local anim_sets =[];
    if (mdl in ::Sakiko_InspectState.Sakiko_AnimCache) {
        anim_sets = ::Sakiko_InspectState.Sakiko_AnimCache[mdl];
    } else {
        local seqList =[];
        for (local i = 0; i < maxSeq; i++) {
            local sn = vm.GetSequenceName(i);
            if (!sn || sn == "Unknown" || sn == "unknown") break;
            local an = vm.GetSequenceActivityName(i);
            seqList.append({ sn = sn.tolower(), an = an ? an.tolower() : "" });
        }
        local prefixes =["itempickup", "helpinghand", "inspect", "item"];
        foreach(p in prefixes) {
            local c_ext = -1, c_loop = -1, c_ret = -1;
            for (local i = 0; i < seqList.len(); i++) {
                local sn = seqList[i].sn;
                local an = seqList[i].an;
                if (sn.find(p) != null || an.find(p) != null) {
                    if (sn.find("extend") != null || an.find("extend") != null) c_ext = i;
                    else if (sn.find("retract") != null || an.find("retract") != null) c_ret = i;
                    else if (sn.find("loop") != null || an.find("loop") != null || sn.find("idle") != null || an.find("idle") != null) c_loop = i;
                }
            }
            if (c_ext != -1 || c_loop != -1 || c_ret != -1) {
                local duplicate = false;
                foreach(s in anim_sets) { if (s.ext == c_ext && s.loop == c_loop && s.ret == c_ret) duplicate = true; }
                if (!duplicate) anim_sets.append({ ext = c_ext, loop = c_loop, ret = c_ret });
            }
        }
        if (anim_sets.len() == 0) {
            local c_ext = -1, c_loop = -1, c_ret = -1;
            for (local i = 0; i < seqList.len(); i++) {
                local sn = seqList[i].sn;
                local an = seqList[i].an;
                if (sn.find("extend") != null || an.find("extend") != null) c_ext = i;
                else if (sn.find("retract") != null || an.find("retract") != null) c_ret = i;
                else if (sn.find("loop") != null || an.find("loop") != null || sn.find("idle") != null || an.find("idle") != null) c_loop = i;
            }
            if (c_ext != -1 || c_loop != -1 || c_ret != -1) {
                anim_sets.append({ ext = c_ext, loop = c_loop, ret = c_ret });
            }
        }
        ::Sakiko_InspectState.Sakiko_AnimCache[mdl] <- anim_sets;
    }
    local chosen = { ext = -1, loop = -1, ret = -1 };
    if (anim_sets.len() > 0) chosen = anim_sets[RandomInt(0, anim_sets.len() - 1)];
    state.ext = chosen.ext;
    state.loop = chosen.loop;
    state.ret = chosen.ret;
    local first_seq = -1;
    if (state.ext != -1) first_seq = state.ext;
    else if (state.loop != -1) first_seq = state.loop;
    else first_seq = fallbackSeq;
    if (first_seq != -1) {
        state.active = true;
        state.weapon = aw;
        state.last_ani = first_seq;
        NetProps.SetPropInt(vm, "m_nLayerSequence", first_seq);
        NetProps.SetPropInt(vm, "m_nLayer", 0);
        NetProps.SetPropFloat(vm, "m_flLayerStartTime", Time());
        if (aw) NetProps.SetPropInt(aw, "m_helpingHandState", 6);
        local dur = vm.GetSequenceDuration(first_seq);
        if (dur <= 0.0) dur = 1.0;
        if (first_seq == state.ext && state.loop != -1) {
            local delay = dur - 0.1; if (delay < 0.0) delay = 0.0;
            DoEntFire("sakiko_inspect_script", "RunScriptCode", "::Sakiko_PlayInspectLoop(" + clientIndex + ")", delay, null, null);
        } else if (first_seq != state.loop) {
            DoEntFire("sakiko_inspect_script", "RunScriptCode", "::Sakiko_ClearInspect(" + clientIndex + ")", dur, null, null);
        }
    }
};
