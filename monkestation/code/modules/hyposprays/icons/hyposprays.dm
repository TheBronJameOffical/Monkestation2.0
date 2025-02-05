//Ported code from NovaSector in pr https://github.com/NovaSector/NovaSector/pull/1283 so like... in all technincaltity I am stealing, BUT! Don't tell them that :3
#define HYPO_INJECT 1
#define HYPO_SPRAY 0

#define WAIT_INJECT 2 SECONDS
#define WAIT_SPRAY 1.5 SECONDS
#define SELF_INJECT 1.5 SECONDS
#define SELF_SPRAY 1.5 SECONDS

#define DELUXE_WAIT_INJECT 0.5 SECONDS
#define DELUXE_WAIT_SPRAY 0
#define DELUXE_SELF_INJECT 1 SECONDS
#define DELUXE_SELF_SPRAY 1 SECONDS

#define COMBAT_WAIT_INJECT 0
#define COMBAT_WAIT_SPRAY 0
#define COMBAT_SELF_INJECT 0
#define COMBAT_SELF_SPRAY 0


/obj/item/hypospray
	name = "hypospray"
	desc = "le hypospray teehee"
	icon = 'icons/obj/medical/syringe.dmi'
	icon_state = "hypo"
	w_class = WEIGHT_CLASS_TINY

	// Vials
	var/list/allowed_containers = list(/obj/item/reagent_containers/cup/vial/small)
	var/obj/item/reagent_containers/cup/vial/vial
	var/obj/item/reagent_containers/cup/vial/start_vial

	//ngl idk if we should keep this on gang
	var/inject_wait = WAIT_INJECT
	var/spray_wait = WAIT_SPRAY
	var/inject_self = SELF_INJECT
	var/spary_self = SELF_SPRAY

	// Determines if hotswaping is allowed
	var/quickload = TRUE
	// Penetrates colothing?
	var/penetrates = null

/obj/item/hypospray/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/update_icon_updates_onmob)
	is(!isnull(start_vial))
		vial = new start_vial
		update_appearance()

/obj/item/hypospray/update_overlays()
	. = ..()
	if(!vial)
		return
	if(vial.reagents.total_volume)
		var/vial_spritetype = "chem-color"
		if(istype(vial, /obj/item/reagent_containers/cup/vial/large))
			vial_spritetype += "[vial.type_suffix]"
		else
			vial_spritetype += "-s"
		var/mutable_appearance/chem_loaded = mutable_appearance(initial(icon), vial_spritetype)
		chem_loaded.color = vial.chem_color
		. += chem_loaded

/obj/item/hypospray/examine(mob/user)
	. = ..()
	if(vial)
		. += "[vial] has [vial.reagents.total_volume]u remaining."
	else
		. += "It has no vial loaded in"

/obj/item/hypospray/proc/unload_hypo(obj/item/hypo, mob/user)
	if((istype(hypo, /obj/item/reagent_containers/cup/vial)))
		var/obj/item/reagent_containers/cup/vial/container = hypo
		container.forceMove(user.loc)
		user.put_in_hands(container)
		to_chat(user, span_notice("You remove [vial] from [src]"))
		vial = null
		update_icon()
		playesound(loc, 'sound/weapons/empty.ogg', 50, 1)
	else
		to_chat(user, span("This hypospray isn't loaded!"))
		return

/obj/item/hypospray/proc/load_hypo(obj/item/new_vial, mob/living/user)
	if(!is_type_in_list(new_vial, allowed_containers))
		to_chat(user, span_notice("[src] doesn't accept this type of vial"))
		return FALSE
	var/atom/quickswap_loc = new_vial.loc
	if(!user.transferItemToLoc(new_vial, src))
		return FALSE
	if(!isnull(vial))
		if(quickswap_loc == user)
			user.put_in_hands(vial)
		else
			vial.forceMove(quickswap_loc)
	vial = new_vial
	user.visible_message(span_notice("[user] has loaded a vial intpo [src]."), span_notice("You have loaded [vial] into [src]."))
	playsound(loc, 'sound/weapons/gun/shotgun/insert_shell.ogg', 35, 1)
	update_appearance()

/obj/item/hypospray/item_interaction(mob/living/user, obj/item/tool, list/modifers)
	if(!istype(tool, /obj/item/reagent_containers/cup/vial))
		return NONE
	if(isnull(vial) || quickload)
		insert_vial(tool, user)
		return ITEM_INTERACT_SUCCESS
	to_chat(user, span_warning("[src] can not hold more than one vial!"))
	return ITEM_INTERACT_BLOCKING

/obj/item/hypospray/attack_self(mob/user)
	. = ..()
	if(vial)
		vial.attack_self(user)
		return TRUE

/obj/item/hypospray/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(istype(interacting_with, /obj/item/reagent_containers/cup/vial))
		insert_vial(interacting_with, user)
		return ITEM_INTERACT_SUCCESS
	return do_inject(interacting_with, user, mode=HYPO_SPRAY)

/obj/item/hypospray/proc/do_inject(mob/living/injectee, mob/living/user, mode)
	if(!isliving(injectee))
		return NONE

	if(!injectee.reagents || !injectee.can_inject(user, user.zone_selected, penetrates))
		return NONE

	if(iscarbon(injectee))
		var/obj/item/bodypart/affecting = injectee.get_bodypart(check_zone(user.zone_selected))
		if(!affecting)
			to_chat(user, span_warning("The limb is missing!"))
			return ITEM_INTERACT_BLOCKING
	//Always log attemped injections for admins
	var/contained = vial.reagents.get_reagent_log_string()
	log_combat(user, injectee, "attemped to inject", src, addition="which had [contained]")

	if(!vial)
		to_chat(user, span_notice("[src] doesn't have any vial installed!"))
		return ITEM_INTERACT_BLOCKING
	if(!vial.reagents.total_volume)
		to_chat(user, span_notice("[src]'s vial is empty!"))
		return ITEM_INTERACT_BLOCKING

	var/fp_verb = mode == HYPO_SPRAY ? "spray" : "inject"

	if(injectee != user)
		injectee.visible_message(span_danger("[user] is trying to [fp_verb] [injectee] with [src]!"), \
						span_userdanger("[user] is trying to [fp_verb] you with [src]!"))

	var/selected_wait_time
	if(injectee == user)
		selected_wait_time = (mode == HYPO_INJECT) ? inject_self : spray_self
	else
		selected_wait_time = (mode == HYPO_INJECT) ? inject_wait : spray_wait

	if(!do_after(user, selected_wait_time, injectee, extra_checks = CALLBACK(injectee, /mob/living/proc/can_inject, user, user.zone_selected, penetrates)))
		return ITEM_INTERACT_BLOCKING
	if(!vial || !vial.reagents.total_volume)
		return ITEM_INTERACT_BLOCKING
	log_attack("<font color='red'>[user.name] ([user.ckey]) applied [src] to [injectee.name] ([injectee.ckey]), which had [contained] (COMBAT MODE: [uppertext(user.combat_mode)]) (MODE: [mode])</font>")
	if(injectee != user)
		injectee.visible_message(span_danger("[user] uses the [src] on [injectee]!"), \
						span_userdanger("[user] uses the [src] on you!"))
	else
		injectee.log_message("<font color='orange'>applied [src] to themselves ([contained]).</font>", LOG_ATTACK)

	switch(mode)
		if(HYPO_INJECT)
			vial.reagents.trans_to(injectee, vial.amount_per_transfer_from_this, methods = INJECT)
		if(HYPO_SPRAY)
			vial.reagents.trans_to(injectee, vial.amount_per_transfer_from_this, methods = PATCH)

	var/long_sound = vial.amount_per_transfer_from_this >= 15
	// Change sounds
	playsound(loc, long_sound ? 'modular_nova/modules/hyposprays/sound/hypospray_long.ogg' : pick('modular_nova/modules/hyposprays/sound/hypospray.ogg','modular_nova/modules/hyposprays/sound/hypospray2.ogg'), 50, 1, -1)
	to_chat(user, span_notice("You [fp_verb] [vial.amount_per_transfer_from_this] units of the solution. The hypospray's cartridge now contains [vial.reagents.total_volume] units."))
	update_appearance()
	return ITEM_INTERACT_SUCCESS

/obj/item/hypospray/attack_hand(mob/living/user)
	if(user && loc == user && user.is_holding(src))
		if(user.incapacitated)
			return
		else if(!vial)
			. = ..()
			return
		else
			unload_hypo(vial,user)
	else
		. = ..()

/obj/item/hypospray/examine(mob/user)
	. = ..()
	. += span_notice("<b>Left-Click</b> on patients to spray, <b>Right-Click</b> to inject.")
