-- Sailing highlight rules — port of tt_dw's
-- ~/code/3p/tt_dw/scripts/missions/sailing/colours.tin.
--
-- Declarative — every call is a side-effect mud.style registration, so
-- this module just needs to be `require`d once from main.lua. Returns
-- an empty table for the require cache.
--
-- Translation rules used throughout:
--   %*           → .*
--   {a|b|c}      → (?:a|b|c)
--   %1, %2, ...  → (.+?) capture groups (numbered left-to-right)
--   %.           → .
--   Anchors      → tintin's ^...$ stays as ^...$ in Rust regex.

-- ---------------------------------------------------------------------
-- === Monster phase ===
-- ---------------------------------------------------------------------

mud.style([[^.*A massive (?:kraken|sea serpent) crests from the water ahead of the ship.*$]], { fg = "light orange" })
mud.style([[^.*  That sounds like it might be serious\.$]], { fg = "light orange" })


mud.style([[^.*(?:The|the) sea serpent (?:lunges|reaches|strikes).*Run!.*$]], { fg = "light red", priority = 200 })
mud.style([[^.*(?:The|the) sea serpent (?:lunges|reaches|strikes).*$]],       { fg = "pink",      priority = 100 })
mud.style([[^.*tentacle snakes around.*$]],                                                    { fg = "light red"    })
mud.style([[^.*swing.*(?:cutting|scoring) a (?:shallow|small|light) scratch into its rubbery skin\..*$]], { fg = "light green" })
mud.style([[^.*You cannot concentrate enough to throw.*$]],                                    { fg = "light orange" })
mud.style([[^The sea serpent aborts its strike and draws its head back, looking for its missing prey\.$]], { fg = "light green" })
mud.style([[^The sea serpent's venomous fangs gouge long scratches in the deck as its strike misses\.$]], { fg = "light green" })
mud.style([[^The sea serpent chomps down on nothing but air, its prey having escaped\.$]],     { fg = "light green" })

-- The four `#sub` rules in the source recolor the captured object name
-- (e.g. "harpoon", "rope") inside the verbose impact message. In
-- tintin: <039>%1<099> wraps the capture in orange. Here we use
-- mud.style with capture = 1 and fg = "orange".
mud.style([[^.*arcs through the air and lodges (.+?) on .*$]],      { capture = 1, fg = "orange" })
mud.style([[^.*arcs through the air and lodges (.+?) in .*$]],      { capture = 1, fg = "orange" })
mud.style([[^.*arcs through the air and lodges (.+?) into .*$]],    { capture = 1, fg = "orange" })
mud.style([[^.*arcs through the air and lodges (.+?) between .*$]], { capture = 1, fg = "orange" })

-- The eight follow-on `#sub`s color the body-part name when a projectile
-- hits the kraken/serpent. Tintin's source numbers this as %2 (because
-- %1 was the projectile in the verbose pattern), but our Rust regex
-- only captures the body part — so it's capture index 1.
mud.style([[^.*arcs through the air and strikes the kraken (.+?) on .*$]],      { capture = 1, fg = "orange" })
mud.style([[^.*arcs through the air and strikes the kraken (.+?) in .*$]],      { capture = 1, fg = "orange" })
mud.style([[^.*arcs through the air and strikes the kraken (.+?) into .*$]],    { capture = 1, fg = "orange" })
mud.style([[^.*arcs through the air and strikes the kraken (.+?) between .*$]], { capture = 1, fg = "orange" })
mud.style([[^.*arcs through the air and strikes the sea serpent (.+?) on .*$]],      { capture = 1, fg = "orange" })
mud.style([[^.*arcs through the air and strikes the sea serpent (.+?) in .*$]],      { capture = 1, fg = "orange" })
mud.style([[^.*arcs through the air and strikes the sea serpent (.+?) into .*$]],    { capture = 1, fg = "orange" })
mud.style([[^.*arcs through the air and strikes the sea serpent (.+?) between .*$]], { capture = 1, fg = "orange" })

-- ---------------------------------------------------------------------
-- === Wrangling ===
-- ---------------------------------------------------------------------

mud.style([[^.*dragon looks up at .* accidentally spraying flame over the floorboards\.$]], { fg = "light red" })
mud.style([[^.*A little bell on the MK I Boiling Engine rings to indicate that it's out of water\..*$]], { fg = "light red" })

-- The `#sub` rule colors both captured values (boiler temperature and pressure)
-- orange. One mud.style call with `captures = {1, 2}` paints both capture
-- groups with the same fg.
mud.style([[^According to the dials on the side, it seems to be (.+?) and (.+?)\.]], { captures = {1, 2}, fg = "orange" })

mud.style([[^The MK I Boiling Engine makes a sizzling sound as it boils dry\.$]], { fg = "yellow" })

mud.style([[(very (?:bored|hungry))]],         { capture = 1, fg = "red"    })
mud.style([[(somewhat (?:bored|hungry))]],     { capture = 1, fg = "orange" })
mud.style([[(a little (?:bored|hungry))]],     { capture = 1, fg = "yellow" })
mud.style([[(not at all (?:bored|hungry))]],   { capture = 1, fg = "green"  })

mud.style([[^.*(finishe. (?:off the last|the contents) of the.*)$]],              { capture = 1, fg = "green"  })
mud.style([[^.*(where it sits down and starts breathing fire onto the Boiling Engine\..*)$]], { capture = 1, fg = "green" })
mud.style([[^.*(looking fuzzily confused\..*)$]], { capture = 1, fg = "yellow" })

mud.style([[(small red circle)]],                                                  { capture = 1, fg = "red"   })
mud.style([[(Aggy the pale green swamp dragon)]],                                  { capture = 1, fg = "cyan"  })
mud.style([[(Idiot the bright red swamp dragon)]],                                 { capture = 1, fg = "cyan"  })
mud.style([[(Bitey the sky blue swamp dragon)]],                                   { capture = 1, fg = "cyan"  })
mud.style([[(Nugget the dark purple swamp dragon)]],                               { capture = 1, fg = "cyan"  })
mud.style([[(flutters after the rubber toy ball and brings it back to you excitedly)]], { capture = 1, fg = "green" })
mud.style([[(it climbs atop the pile of rubber scraps and sits there triumphantly\.)]], { capture = 1, fg = "green" })

-- ---------------------------------------------------------------------
-- === Fires ===
-- ---------------------------------------------------------------------

mud.style([[^.*The room catches on fire!.*$]],                                    { fg = "light red"  })
mud.style([[^.*stamp.*out the fire\..*$]],                                         { fg = "green"      })
mud.style([[^.*a small fire has started here.*$]],                                { fg = "light red"  })
mud.style([[^.*Fire fills the room, burning merrily without regard.*$]],          { fg = "light red"  })
mud.style([[^.*putting it out in a cloud of steam\.$]],                            { fg = "green"      })
mud.style([[^.*putting some of it out in a cloud of steam\.$]],                    { fg = "yellow"     })
mud.style([[^.*(?:several|Several) blazes are eagerly licking at the floorboards.*$]], { fg = "light red" })
mud.style([[^.*the room is filled with a huge conflagration.*sparks spilling.*$]], { fg = "light red"  })
mud.style([[^.*(?:flickering|Flickering) firelight.*$]],                           { fg = "light red"  })
mud.style([[^The fire intensifies\.$]],                                            { fg = "light red"  })
mud.style([[^.*The water on the floor washes over the fire, putting it out in a gush of steam\..*$]], { fg = "green" })

-- ---------------------------------------------------------------------
-- === Ice ===
-- ---------------------------------------------------------------------

mud.style([[^.*ice has formed.*$]],                   { fg = "light blue" })
mud.style([[^.*ice might be forming on the hull.*$]], { fg = "light blue" })
mud.style([[^.*slippery layer of ice\..*$]],           { fg = "light blue" })

-- ---------------------------------------------------------------------
-- === Decking ===
-- ---------------------------------------------------------------------

mud.style([[^.*(?:you|You) feel too tired to tie any knots.*$]],                                    { fg = "light orange" })
mud.style([[^.*(?:you|You) manage to shatter all the remaining sea ice on the hull\..*$]],           { fg = "green"        })
mud.style([[^.*(?:you|You) tie .* of rope securely.*$]],                                              { fg = "green"        })
mud.style([[^.*Under the strain, your rope gives up the ghost and unravels completely into wispy threads that float away in the wind\..*$]], { fg = "light red" })
mud.style([[^.*You try to tie.*$]],                                                                    { fg = "light red"    })
mud.style([[^You tie one of the cargo crates down securely .* with (?:one of )?the coils? of rope, preventing it from sliding\.]], { fg = "green" })
mud.style([[^You tie one of the cargo crates down securely in a running bowline with the coil of rope, preventing it from sliding\.]], { fg = "green" })

-- Hull fixing
mud.style([[^You .* onto the ship's hull, sealing some of the worst holes in it\.]], { fg = "green" })
mud.style([[^You .* onto the ship's hull, bringing it back to top condition\.]],     { fg = "green" })

-- Ice (status strings — these match anywhere in the line, so no anchors)
mud.style([[(a colossal amount of sea ice)]], { capture = 1, fg = "red"    })
mud.style([[(a thick mass of sea ice)]],      { capture = 1, fg = "red"    })
mud.style([[(a thin layer of sea ice)]],      { capture = 1, fg = "yellow" })
mud.style([[(a few patches of sea ice)]],     { capture = 1, fg = "yellow" })

-- Weed
mud.style([[(a few strands of glowing dire seaweed)]], { capture = 1, fg = "red" })
mud.style([[(a thin covering of glowing dire seaweed)]], { capture = 1, fg = "red" })

mud.style([[^.*The ship plows through a field of floating dire seaweed, some of which glows green and latches onto the hull aggressively!.*$]], { fg = "light red" })
mud.style([[^.*Looking like it recognises the shipwright's hammer somehow, (?:some|all) of the (?:remaining )?dire seaweed detaches from the hull and flees into the ocean\..*$]], { fg = "green" })
mud.style([[^.*You see some ice that used to be on the hull drifting off into the sea, accompanied by the sound of seaweedy complaining from below\..*$]], { fg = "yellow" })

-- Hull damage
mud.style([[(badly cracked)]],                       { capture = 1, fg = "red"    })
mud.style([[(bears the marks of multiple impacts)]], { capture = 1, fg = "red"    })
mud.style([[(rather dented)]],                       { capture = 1, fg = "yellow" })
mud.style([[(a little scuffed up)]],                 { capture = 1, fg = "yellow" })
mud.style([[(in perfect condition)]],                { capture = 1, fg = "green"  })

-- Ropes
mud.style([[(hanging on by a thread)]], { capture = 1, fg = "red"    })
mud.style([[(very frayed)]],            { capture = 1, fg = "red"    })
mud.style([[(somewhat frayed)]],        { capture = 1, fg = "yellow" })
mud.style([[(a little frayed)]],        { capture = 1, fg = "yellow" })

-- ---------------------------------------------------------------------
-- === Helming ===
-- ---------------------------------------------------------------------

mud.style([[^.*round a few times before escaping pointing in a different direction.*$]], { fg = "light red"    })
mud.style([[^.*Caught in a strong backwards current.*$]],                                  { fg = "light orange" })
mud.style([[^.*Caught in a strong forwards current.*$]],                                   { fg = "yellow"       })
mud.style([[^.*Steam whistles from the smokestack as the ship begins to move\..*$]],         { fg = "yellow"       })
mud.style([[^.*The impact knocks the ship slightly off course.*$]],                        { fg = "light red"    })
mud.style([[^.*The ship abruptly starts spinning in circles\.  After a few rounds, it manages to escape the whirlpool, heading in a different direction from before\.$]], { fg = "light red" })
mud.style([[^.*The steam from the smokestack dwindles to nothing as the ship slows to a halt\..*$]], { fg = "light orange" })
mud.style([[^.*The powerful headwind causes.*$]],                                          { fg = "light red"    })
mud.style([[^You feel the ship slow to a halt\.]], { fg = "yellow" })
mud.style([[^You feel the ship begin to move\.]],  { fg = "yellow" })

return {}
