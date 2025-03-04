
/datum/sound_template //Basically a sound datum, but only serves as a way to carry info to soundOutput
	var/file //The sound itself
	var/file_muffled // Muffled variant for those that are deaf
	var/wait = 0
	var/repeat = 0
	var/channel = 0
	var/volume = 100
	var/status = 0 //Sound status flags
	var/frequency = 1
	var/falloff = 1
	var/volume_cat = VOLUME_SFX
	var/range = 0
	var/list/echo
	var/x //Map coordinates, not sound coordinates
	var/y
	var/z
	var/y_s_offset // Vertical sound offset
	var/x_s_offset // Horizontal sound offset

/proc/get_free_channel()
	var/static/cur_chan = 1
	. = cur_chan++
	if(cur_chan > FREE_CHAN_END)
		cur_chan = 1

//Proc used to play a sound effect. Avoid using this proc for non-IC sounds, as there are others
//source: self-explanatory.
//soundin: the .ogg to use.
//vol: the initial volume of the sound, 0 is no sound at all, 75 is loud queen screech.
//freq: the frequency of the sound. Setting it to 1 will assign it a random frequency
//sound_range: the maximum theoretical range (in tiles) of the sound, by default is equal to the volume.
//vol_cat: the category of this sound, used in client volume. There are 3 volume categories: VOLUME_SFX (Sound effects), VOLUME_AMB (Ambience and Soundscapes) and VOLUME_ADM (Admin sounds and some other stuff)
//channel: use this only when you want to force the sound to play on a specific channel
//status: the regular 4 sound flags
//falloff: max range till sound volume starts dropping as distance increases

/proc/playsound(atom/source, soundin, vol = 100, vary = FALSE, sound_range, vol_cat = VOLUME_SFX, channel = 0, status , falloff = 1, echo, y_s_offset,x_s_offset)
	if(isarea(source))
		error("[source] is an area and is trying to make the sound: [soundin]")
		return FALSE
	var/datum/sound_template/S = new()

	var/sound/SD = soundin
	if(istype(SD))
		S.file = SD.file
		S.wait = SD.wait
		S.repeat = SD.repeat
	else
		S.file = get_sfx(soundin)
	S.channel = channel ? channel : get_free_channel()
	S.status = status
	S.falloff = falloff
	S.volume = vol
	S.volume_cat = vol_cat
	S.echo = echo
	S.y_s_offset = y_s_offset
	S.x_s_offset = x_s_offset
	if(vary != FALSE)
		if(vary > 1)
			S.frequency = vary
		else
			S.frequency = GET_RANDOM_FREQ // Same frequency for everybody

	if(!sound_range)
		sound_range = round(0.25*vol) //if no specific range, the max range is equal to a quarter of the volume.
	S.range = sound_range

	var/turf/turf_source = get_turf(source)
	if(!turf_source || !turf_source.z)
		return FALSE
	S.x = turf_source.x
	S.y = turf_source.y
	S.z = turf_source.z

	if(!SSinterior)
		SSsound.queue(S)
		return S.channel

	var/list/datum/interior/extra_interiors = list()
	// If we're in an interior, range the chunk, then adjust to do so from outside instead
	if(SSinterior.in_interior(turf_source))
		var/datum/interior/VI = SSinterior.get_interior_by_coords(turf_source.x, turf_source.y, turf_source.z)
		if(VI?.ready)
			extra_interiors |= VI
			if(VI.exterior)
				var/turf/new_turf_source = get_turf(VI.exterior)
				S.x = new_turf_source.x
				S.y = new_turf_source.y
				S.z = new_turf_source.z
			else sound_range = 0
	// Range for 'nearby interiors' aswell
	for(var/datum/interior/VI in SSinterior.interiors)
		if(VI?.ready && VI.exterior?.z == turf_source.z && get_dist(VI.exterior, turf_source) <= sound_range)
			extra_interiors |= VI

	SSsound.queue(S, null, extra_interiors)
	return S.channel



//This is the replacement for playsound_local. Use this for sending sounds directly to a client
/proc/playsound_client(client/C, soundin, atom/origin, vol = 100, random_freq, vol_cat = VOLUME_SFX, channel = 0, status, list/echo, y_s_offset, x_s_offset)
	if(!istype(C) || !C.soundOutput) return FALSE
	var/datum/sound_template/S = new()
	if(origin)
		var/turf/T = get_turf(origin)
		if(T)
			S.x = T.x
			S.y = T.y
			S.z = T.z
	var/sound/SD = soundin
	if(istype(SD))
		S.file = SD.file
		S.wait = SD.wait
		S.repeat = SD.repeat
	else
		S.file = get_sfx(soundin)

	if(random_freq)
		S.frequency = GET_RANDOM_FREQ
	S.volume = vol
	S.volume_cat = vol_cat
	S.channel = channel
	S.status = status
	S.echo = echo
	S.y_s_offset = y_s_offset
	S.x_s_offset = x_s_offset
	SSsound.queue(S, list(C))

/// Plays sound to all mobs that are map-level contents of an area
/proc/playsound_area(area/A, soundin, vol = 100, channel = 0, status, vol_cat = VOLUME_SFX, list/echo, y_s_offset, x_s_offset)
	if(!isarea(A))
		return FALSE
	var/datum/sound_template/S = new()
	S.file = soundin
	S.volume = vol
	S.channel = channel
	S.status = status
	S.volume_cat = vol_cat

	var/list/hearers = list()
	for(var/mob/living/M in A.contents)
		if(!M || !M.client || !M.client.soundOutput)
			continue
		hearers += M.client
	SSsound.queue(S, hearers)

/client/proc/playtitlemusic()
	if(!SSticker?.login_music)
		return FALSE
	if(prefs && prefs.toggles_sound & SOUND_LOBBY)
		playsound_client(src, SSticker.login_music, null, 70, 0, VOLUME_LOBBY, SOUND_CHANNEL_LOBBY, SOUND_STREAM)


/// Play sound for all on-map clients on a given Z-level. Good for ambient sounds.
/proc/playsound_z(z, soundin, volume = 100, vol_cat = VOLUME_SFX, echo, y_s_offset, x_s_offset)
	var/datum/sound_template/S = new()
	S.file = soundin
	S.volume = volume
	S.channel = SOUND_CHANNEL_Z
	S.volume_cat = vol_cat
	S.echo = echo
	S.y_s_offset = y_s_offset
	S.x_s_offset = x_s_offset
	var/list/hearers = list()
	for(var/mob/M in GLOB.player_list)
		if((M.z in z) && M.client.soundOutput)
			hearers += M.client
	SSsound.queue(S, hearers)

// The pick() proc has a built-in chance that can be added to any option by adding ,X; to the end of an option, where X is the % chance it will play.
/proc/get_sfx(S)
	if(istext(S))
		switch(S)
			// General effects
			if("shatter")
				S = pick('sound/effects/Glassbr1.ogg','sound/effects/Glassbr2.ogg','sound/effects/Glassbr3.ogg')
			if("windowshatter") //meaty window shattering sound
				S = pick('sound/effects/window_shatter1.ogg','sound/effects/window_shatter2.ogg','sound/effects/window_shatter3.ogg')
			if("glassbreak") //small breaks for bottles/etc.
				S = pick('sound/effects/glassbreak1.ogg','sound/effects/glassbreak2.ogg','sound/effects/glassbreak3.ogg','sound/effects/glassbreak4.ogg')
			if("explosion")
				S = pick('sound/effects/explosion1.ogg','sound/effects/explosion2.ogg','sound/effects/explosion3.ogg','sound/effects/explosion4.ogg','sound/effects/explosion5.ogg')
			if("bigboom")
				S = pick('sound/effects/bigboom1.ogg','sound/effects/bigboom2.ogg','sound/effects/bigboom3.ogg','sound/effects/bigboom4.ogg')
			if("sparks")
				S = pick('sound/effects/sparks1.ogg','sound/effects/sparks2.ogg','sound/effects/sparks3.ogg','sound/effects/sparks4.ogg')
			if("rustle")
				S = pick('sound/effects/rustle1.ogg','sound/effects/rustle2.ogg','sound/effects/rustle3.ogg','sound/effects/rustle4.ogg','sound/effects/rustle5.ogg')
			if("toolbox")
				S = pick('sound/effects/toolbox.ogg')
			if("pillbottle")
				S = pick('sound/effects/pillbottle.ogg')
			if("rip")
				S = pick('sound/effects/rip1.ogg','sound/effects/rip2.ogg')
			if("lighter")
				S = pick('sound/effects/lighter1.ogg','sound/effects/lighter2.ogg','sound/effects/lighter3.ogg')
			if("zippo_open")
				S = pick('sound/effects/zippo_open.ogg')
			if("zippo_close")
				S = pick('sound/effects/zippo_close.ogg')
			if("bonk") //somewhat quiet, increase volume
				S = pick('sound/machines/bonk.ogg')
			if("cane_step")
				S = pick('sound/items/cane_step_1.ogg', 'sound/items/cane_step_2.ogg', 'sound/items/cane_step_3.ogg', 'sound/items/cane_step_4.ogg', 'sound/items/cane_step_5.ogg', )
			if("match")
				S = pick('sound/effects/match.ogg')
			if("punch")
				S = pick('sound/weapons/punch1.ogg','sound/weapons/punch2.ogg','sound/weapons/punch3.ogg','sound/weapons/punch4.ogg')
			if("swing_hit")
				S = pick('sound/weapons/genhit1.ogg', 'sound/weapons/genhit2.ogg', 'sound/weapons/genhit3.ogg')
			if("clan_sword_hit")
				S = pick('sound/weapons/clan_sword_hit_1.ogg', 'sound/weapons/clan_sword_hit_2.ogg')
			if("slam")
				S = pick('sound/effects/slam1.ogg','sound/effects/slam2.ogg','sound/effects/slam3.ogg')
			if("pageturn")
				S = pick('sound/effects/pageturn1.ogg', 'sound/effects/pageturn2.ogg','sound/effects/pageturn3.ogg')
			if("terminal_button")
				S = pick('sound/machines/terminal_button01.ogg', 'sound/machines/terminal_button02.ogg', 'sound/machines/terminal_button03.ogg','sound/machines/terminal_button04.ogg', 'sound/machines/terminal_button05.ogg', 'sound/machines/terminal_button06.ogg', 'sound/machines/terminal_button07.ogg', 'sound/machines/terminal_button08.ogg')
			if("keyboard")
				S = pick('sound/machines/keyboard1.ogg', 'sound/machines/keyboard2.ogg','sound/machines/keyboard3.ogg')
			if("keyboard_alt")
				S = pick('sound/machines/computer_typing4.ogg', 'sound/machines/computer_typing5.ogg', 'sound/machines/computer_typing6.ogg')
			if("gunrustle")
				S = pick('sound/effects/gunrustle1.ogg', 'sound/effects/gunrustle2.ogg','sound/effects/gunrustle3.ogg')
			if("gunequip")
				S = pick('sound/handling/gunequip1.ogg','sound/handling/gunequip2.ogg','sound/handling/gunequip3.ogg')
			if("shotgunpump")
				S = pick('sound/weapons/shotgunpump1.ogg','sound/weapons/shotgunpump2.ogg')
			if("clothingrustle")
				S = pick('sound/handling/clothingrustle1.ogg', 'sound/handling/clothingrustle2.ogg','sound/handling/clothingrustle3.ogg','sound/handling/clothingrustle4.ogg','sound/handling/clothingrustle5.ogg')
			if("armorequip")
				S = pick('sound/handling/armorequip_1.ogg','sound/handling/armorequip_2.ogg')
			if("pry")
				S = pick('sound/effects/pry1.ogg', 'sound/effects/pry2.ogg','sound/effects/pry3.ogg','sound/effects/pry4.ogg')
			if("metalbang")
				S = pick('sound/effects/thud1.ogg','sound/effects/thud2.ogg','sound/effects/thud3.ogg')
			if("paper_writing")
				S = pick('sound/items/writing_noises/paper_writing_1.wav', 'sound/items/writing_noises/paper_writing_2.wav', 'sound/items/writing_noises/paper_writing_3.wav', 'sound/items/writing_noises/paper_writing_4.ogg')
			// Weapons/bullets
			if("shell_load")
				S = pick('sound/weapons/shell_load1.ogg','sound/weapons/shell_load2.ogg','sound/weapons/shell_load3.ogg','sound/weapons/shell_load4.ogg')
			if("ballistic_hit")
				S = pick('sound/bullets/bullet_impact1.ogg','sound/bullets/bullet_impact2.ogg','sound/bullets/bullet_impact1.ogg','sound/bullets/impact_flesh_1.ogg','sound/bullets/impact_flesh_2.ogg','sound/bullets/impact_flesh_3.ogg','sound/bullets/impact_flesh_4.ogg')
			if("ballistic_armor")
				S = pick('sound/bullets/bullet_armor1.ogg','sound/bullets/bullet_armor2.ogg','sound/bullets/bullet_armor3.ogg','sound/bullets/bullet_armor4.ogg')
			if("ballistic_miss")
				S = pick('sound/bullets/bullet_miss1.ogg','sound/bullets/bullet_miss2.ogg','sound/bullets/bullet_miss3.ogg','sound/bullets/bullet_miss4.ogg')
			if("ballistic_bounce")
				S = pick('sound/bullets/bullet_ricochet1.ogg','sound/bullets/bullet_ricochet2.ogg','sound/bullets/bullet_ricochet3.ogg','sound/bullets/bullet_ricochet4.ogg','sound/bullets/bullet_ricochet5.ogg','sound/bullets/bullet_ricochet6.ogg','sound/bullets/bullet_ricochet7.ogg','sound/bullets/bullet_ricochet8.ogg')
			if("ballistic_shield_hit")
				S = pick('sound/bullets/shield_impact_c1.ogg','sound/bullets/shield_impact_c2.ogg','sound/bullets/shield_impact_c3.ogg','sound/bullets/shield_impact_c4.ogg')
			if("shield_shatter")
				S = pick('sound/bullets/shield_break_c1.ogg')
			if("rocket_bounce")
				S = pick('sound/bullets/rocket_ricochet1.ogg','sound/bullets/rocket_ricochet2.ogg','sound/bullets/rocket_ricochet3.ogg')
			if("energy_hit")
				S = pick('sound/bullets/energy_impact1.ogg')
			if("energy_miss")
				S = pick('sound/bullets/energy_miss1.ogg')
			if("energy_bounce")
				S = pick('sound/bullets/energy_ricochet1.ogg')
			if("alloy_hit")
				S = pick('sound/bullets/spear_impact1.ogg')
			if("alloy_armor")
				S = pick('sound/bullets/spear_armor1.ogg')
			if("alloy_bounce")
				S = pick('sound/bullets/spear_ricochet1.ogg','sound/bullets/spear_ricochet2.ogg')
			if("gun_silenced")
				S = pick('sound/weapons/gun_silenced_shot1.ogg','sound/weapons/gun_silenced_shot2.ogg')
			if("gun_pulse")
				S = pick('sound/weapons/gun_m41a_1.ogg','sound/weapons/gun_m41a_2.ogg','sound/weapons/gun_m41a_3.ogg','sound/weapons/gun_m41a_4.ogg','sound/weapons/gun_m41a_5.ogg','sound/weapons/gun_m41a_6.ogg')
			if("gun_smartgun")
				S = pick('sound/weapons/gun_smartgun1.ogg', 'sound/weapons/gun_smartgun2.ogg', 'sound/weapons/gun_smartgun3.ogg', 'sound/weapons/gun_smartgun4.ogg')
			if("gun_smartgun_rattle")
				S = pick('sound/weapons/gun_smartgun1_rattle.ogg', 'sound/weapons/gun_smartgun2_rattle.ogg', 'sound/weapons/gun_smartgun3_rattle.ogg', 'sound/weapons/gun_smartgun4_rattle.ogg')
			if("gun_jam_rack")
				S = pick('sound/weapons/handling/gun_jam_rack_1.ogg', 'sound/weapons/handling/gun_jam_rack_2.ogg', 'sound/weapons/handling/gun_jam_rack_3.ogg')
			//A:CM gun sounds
			if("gun_shotgun_tactical")
				S = pick('sound/weapons/gun_shotgun_tactical_1.ogg','sound/weapons/gun_shotgun_tactical_2.ogg','sound/weapons/gun_shotgun_tactical_3.ogg','sound/weapons/gun_shotgun_tactical_4.ogg')
			if("m4a3")
				S = pick('sound/weapons/gun_m4a3_1.ogg','sound/weapons/gun_m4a3_2.ogg','sound/weapons/gun_m4a3_3.ogg','sound/weapons/gun_m4a3_4.ogg','sound/weapons/gun_m4a3_5.ogg')
			if("88m4")
				S = pick('sound/weapons/gun_88m4_v7.ogg')
			if("gun_casing_shotgun")
				S = pick ('sound/bullets/bulletcasing_shotgun_fall1.ogg')
			if("gun_nsg23")
				S = pick('sound/weapons/gun_nsg23_1.ogg','sound/weapons/gun_nsg23_2.ogg')
			if("gun_pkd")
				S = pick('sound/weapons/gun_pkd_fire01.ogg','sound/weapons/gun_pkd_fire02.ogg','sound/weapons/gun_pkd_fire03.ogg')

			// Xeno
			if("acid_hit")
				S = pick('sound/bullets/acid_impact1.ogg')
			if("acid_strike")
				S = pick('sound/weapons/alien_acidstrike1.ogg','sound/weapons/alien_acidstrike2.ogg')
			if("acid_spit")
				S = pick('sound/voice/alien_spitacid.ogg','sound/voice/alien_spitacid2.ogg')
			if("acid_sizzle")
				S = pick('sound/effects/acid_sizzle1.ogg','sound/effects/acid_sizzle2.ogg','sound/effects/acid_sizzle3.ogg','sound/effects/acid_sizzle4.ogg')
			if("alien_doorpry")
				S = pick('sound/effects/alien_doorpry1.ogg','sound/effects/alien_doorpry2.ogg')
			if("acid_bounce")
				S = pick('sound/bullets/acid_impact1.ogg')
			if("alien_claw_flesh")
				S = pick('sound/weapons/alien_claw_flesh1.ogg','sound/weapons/alien_claw_flesh2.ogg','sound/weapons/alien_claw_flesh3.ogg','sound/weapons/alien_claw_flesh4.ogg','sound/weapons/alien_claw_flesh5.ogg','sound/weapons/alien_claw_flesh6.ogg')
			if("alien_claw_metal")
				S = pick('sound/weapons/alien_claw_metal1.ogg','sound/weapons/alien_claw_metal2.ogg','sound/weapons/alien_claw_metal3.ogg')
			if("alien_bite")
				S = pick('sound/weapons/alien_bite1.ogg','sound/weapons/alien_bite2.ogg')
			if("alien_footstep_large")
				S = pick('sound/effects/alien_footstep_large1.ogg','sound/effects/alien_footstep_large2.ogg','sound/effects/alien_footstep_large3.ogg')
			if("alien_footstep_medium")
				S = pick('sound/effects/alien_footstep_medium1.ogg','sound/effects/alien_footstep_medium2.ogg','sound/effects/alien_footstep_medium3.ogg')
			if("alien_charge")
				S = pick('sound/effects/alien_footstep_charge1.ogg','sound/effects/alien_footstep_charge2.ogg','sound/effects/alien_footstep_charge3.ogg')
			if("alien_resin_build")
				S = pick('sound/effects/alien_resin_build1.ogg','sound/effects/alien_resin_build2.ogg','sound/effects/alien_resin_build3.ogg')
			if("alien_resin_break")
				S = pick('sound/effects/alien_resin_break1.ogg','sound/effects/alien_resin_break2.ogg','sound/effects/alien_resin_break3.ogg')
			if("alien_resin_move")
				S = pick('sound/effects/alien_resin_move1.ogg','sound/effects/alien_resin_move2.ogg')
			if("alien_talk")
				S = pick('sound/voice/alien_talk.ogg','sound/voice/alien_talk2.ogg','sound/voice/alien_talk3.ogg')
			if("hiss_talk")
				S = pick('sound/voice/hiss2.ogg','sound/voice/hiss3.ogg','sound/voice/hiss4.ogg')
			if("alien_growl")
				S = pick('sound/voice/alien_growl1.ogg','sound/voice/alien_growl2.ogg','sound/voice/alien_growl3.ogg')
			if("alien_hiss")
				S = pick('sound/voice/alien_hiss1.ogg','sound/voice/alien_hiss2.ogg','sound/voice/alien_hiss3.ogg')
			if("alien_tail_swipe")
				S = pick('sound/effects/alien_tail_swipe1.ogg','sound/effects/alien_tail_swipe2.ogg','sound/effects/alien_tail_swipe3.ogg')
			if("alien_help")
				S = pick('sound/voice/alien_help1.ogg','sound/voice/alien_help2.ogg','sound/voice/alien_help3.ogg')
			if("alien_drool")
				S = pick('sound/voice/alien_drool1.ogg','sound/voice/alien_drool2.ogg')
			if("alien_roar")
				S = pick('sound/voice/alien_roar1.ogg','sound/voice/alien_roar2.ogg','sound/voice/alien_roar3.ogg','sound/voice/alien_roar4.ogg','sound/voice/alien_roar5.ogg','sound/voice/alien_roar6.ogg')
			if("alien_roar_larva")
				S = pick('sound/voice/alien_roar_larva1.ogg','sound/voice/alien_roar_larva2.ogg')
			if("queen")
				S = pick('sound/voice/alien_queen_command.ogg','sound/voice/alien_queen_command2.ogg','sound/voice/alien_queen_command3.ogg')
			// Human
			if("male_scream")
				S = pick('sound/voice/human_male_scream_1.ogg','sound/voice/human_male_scream_2.ogg','sound/voice/human_male_scream_3.ogg','sound/voice/human_male_scream_4.ogg',5;'sound/voice/human_male_scream_5.ogg',5;'sound/voice/human_jackson_scream.ogg',5;'sound/voice/human_ack_scream.ogg')
			if("male_pain")
				S = pick('sound/voice/human_male_pain_1.ogg','sound/voice/human_male_pain_2.ogg','sound/voice/human_male_pain_3.ogg',5;'sound/voice/tomscream.ogg',5;'sound/voice/human_bobby_pain.ogg',5;'sound/voice/human_tantrum_scream.ogg', 5;'sound/voice/human_male_pain_rare_1.ogg')
			if("male_fragout")
				S = pick('sound/voice/human_male_grenadethrow_1.ogg', 'sound/voice/human_male_grenadethrow_2.ogg', 'sound/voice/human_male_grenadethrow_3.ogg')
			if("male_warcry")
				S = pick('sound/voice/warcry/male_go.ogg', 'sound/voice/warcry/male_attack.ogg', 'sound/voice/warcry/male_charge.ogg', 'sound/voice/warcry/male_charge2.ogg', 'sound/voice/warcry/warcry_male_1.ogg', 'sound/voice/warcry/warcry_male_2.ogg', 'sound/voice/warcry/warcry_male_3.ogg', 'sound/voice/warcry/warcry_male_4.ogg', 'sound/voice/warcry/warcry_male_5.ogg', 'sound/voice/warcry/warcry_male_6.ogg', 'sound/voice/warcry/warcry_male_7.ogg', 'sound/voice/warcry/warcry_male_8.ogg', 'sound/voice/warcry/warcry_male_9.ogg', 'sound/voice/warcry/warcry_male_10.ogg', 'sound/voice/warcry/warcry_male_11.ogg', 'sound/voice/warcry/warcry_male_12.ogg', 'sound/voice/warcry/warcry_male_13.ogg', 'sound/voice/warcry/warcry_male_14.ogg', 'sound/voice/warcry/warcry_male_15.ogg', 'sound/voice/warcry/warcry_male_16.ogg', 'sound/voice/warcry/warcry_male_17.ogg', 'sound/voice/warcry/warcry_male_18.ogg', 'sound/voice/warcry/warcry_male_19.ogg', 'sound/voice/warcry/warcry_male_20.ogg', 'sound/voice/warcry/warcry_male_21.ogg', 'sound/voice/warcry/warcry_male_22.ogg', 'sound/voice/warcry/warcry_male_23.ogg', 'sound/voice/warcry/warcry_male_24.ogg', 'sound/voice/warcry/warcry_male_25.ogg', 'sound/voice/warcry/warcry_male_26.ogg', 'sound/voice/warcry/warcry_male_27.ogg', 'sound/voice/warcry/warcry_male_28.ogg', 'sound/voice/warcry/warcry_male_29.ogg', 'sound/voice/warcry/warcry_male_30.ogg', 'sound/voice/warcry/warcry_male_31.ogg', 'sound/voice/warcry/warcry_male_32.ogg', 'sound/voice/warcry/warcry_male_33.ogg', 'sound/voice/warcry/warcry_male_34.ogg', 'sound/voice/warcry/warcry_male_35.ogg', 5;'sound/voice/warcry/warcry_male_rare_1.ogg', 5;'sound/voice/warcry/warcry_male_rare_2.ogg', 5;'sound/voice/warcry/warcry_male_rare_3.ogg', 5;'sound/voice/warcry/warcry_male_rare_4.ogg', 5;'sound/voice/warcry/warcry_male_rare_5.ogg')
			if("male_upp_warcry")
				S = pick('sound/voice/upp_warcry/warcry_male_1.ogg', 'sound/voice/upp_warcry/warcry_male_2.ogg')
			if("female_scream")
				S = pick('sound/voice/human_female_scream_1.ogg','sound/voice/human_female_scream_2.ogg','sound/voice/human_female_scream_3.ogg','sound/voice/human_female_scream_4.ogg',5;'sound/voice/human_female_scream_5.ogg')
			if("female_pain")
				S = pick('sound/voice/human_female_pain_1.ogg','sound/voice/human_female_pain_2.ogg','sound/voice/human_female_pain_3.ogg')
			if("female_fragout")
				S = pick("sound/voice/human_female_grenadethrow_1.ogg", 'sound/voice/human_female_grenadethrow_2.ogg', 'sound/voice/human_female_grenadethrow_3.ogg')
			if("female_warcry")
				S = pick('sound/voice/warcry/female_charge.ogg', 'sound/voice/warcry/female_yell1.ogg', 'sound/voice/warcry/warcry_female_1.ogg', 'sound/voice/warcry/warcry_female_2.ogg', 'sound/voice/warcry/warcry_female_3.ogg', 'sound/voice/warcry/warcry_female_4.ogg', 'sound/voice/warcry/warcry_female_5.ogg', 'sound/voice/warcry/warcry_female_6.ogg', 'sound/voice/warcry/warcry_female_7.ogg', 'sound/voice/warcry/warcry_female_8.ogg', 'sound/voice/warcry/warcry_female_9.ogg', 'sound/voice/warcry/warcry_female_10.ogg', 'sound/voice/warcry/warcry_female_11.ogg', 'sound/voice/warcry/warcry_female_12.ogg', 'sound/voice/warcry/warcry_female_13.ogg', 'sound/voice/warcry/warcry_female_14.ogg', 'sound/voice/warcry/warcry_female_15.ogg', 'sound/voice/warcry/warcry_female_16.ogg', 'sound/voice/warcry/warcry_female_17.ogg', 'sound/voice/warcry/warcry_female_18.ogg', 'sound/voice/warcry/warcry_female_19.ogg', 'sound/voice/warcry/warcry_female_20.ogg')
			if("female_upp_warcry")
				S = pick('sound/voice/upp_warcry/warcry_female_1.ogg', 'sound/voice/upp_warcry/warcry_female_2.ogg')
			if("rtb_handset")
				S = pick('sound/machines/telephone/rtb_handset_1.ogg', 'sound/machines/telephone/rtb_handset_2.ogg', 'sound/machines/telephone/rtb_handset_3.ogg', 'sound/machines/telephone/rtb_handset_4.ogg', 'sound/machines/telephone/rtb_handset_5.ogg')
			if("bone_break")
				S = pick('sound/effects/bone_break1.ogg','sound/effects/bone_break2.ogg','sound/effects/bone_break3.ogg','sound/effects/bone_break4.ogg','sound/effects/bone_break5.ogg','sound/effects/bone_break6.ogg','sound/effects/bone_break7.ogg')
			if("plush")
				S = pick('sound/items/plush1.ogg', 'sound/items/plush2.ogg', 'sound/items/plush3.ogg')
			//misc mobs
			if("cat_meow")
				S = pick('sound/voice/cat_meow_1.ogg','sound/voice/cat_meow_2.ogg','sound/voice/cat_meow_3.ogg','sound/voice/cat_meow_4.ogg','sound/voice/cat_meow_5.ogg','sound/voice/cat_meow_6.ogg','sound/voice/cat_meow_7.ogg')
			if("pred_pain")
				S = pick('sound/voice/pred_pain1.ogg','sound/voice/pred_pain2.ogg','sound/voice/pred_pain3.ogg','sound/voice/pred_pain4.ogg','sound/voice/pred_pain5.ogg',5;'sound/voice/pred_pain_rare1.ogg')
			if("clownstep")
				S = pick('sound/effects/clownstep1.ogg', 'sound/effects/clownstep2.ogg')
	return S

/client/proc/generate_sound_queues()
	set name = "Queue sounds"
	set desc = "stress test this bich"
	set category = "Debug"

	var/ammount = tgui_input_number(usr, "How many sounds to queue?")
	var/range = tgui_input_number(usr, "Range")
	var/x = tgui_input_number(usr, "Center X")
	var/y = tgui_input_number(usr, "Center Y")
	var/z = tgui_input_number(usr, "Z level")
	var/datum/sound_template/S
	for(var/i = 1, i <= ammount, i++)
		S = new
		S.file = get_sfx("male_warcry") // warcry has variable length, lots of variations
		S.channel = get_free_channel() // i'm convinced this is bad, but it's here to mirror playsound() behaviour
		S.range = range
		S.x = x
		S.y = y
		S.z = z
		SSsound.queue(S)

/client/proc/sound_debug_query()
	set name = "Dump Playing Client Sounds"
	set desc = "dumps info about locally, playing sounds"
	set category = "Debug"

	for(var/sound/S in SoundQuery())
		UNLINT(to_chat(src, "channel#[S.channel]: [S.status] - [S.file] - len=[S.len], wait=[S.wait], offset=[S.offset], repeat=[S.repeat]")) // unlint until spacemandmm suite-1.7
