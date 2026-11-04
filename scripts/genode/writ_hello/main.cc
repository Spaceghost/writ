/*
 * main.cc for writ_hello - Genode bring-up probe, not Writ implementation.
 *
 * The standard minimal Genode component: its only effect is one line on the
 * LOG session routed to it by its parent (init). It holds no Writ policy and
 * exercises no authority beyond the sessions init grants in writ_hello.run.
 */

#include <base/component.h>
#include <base/log.h>

void Component::construct(Genode::Env &)
{
	Genode::log("writ_hello: component constructed on Genode");
}
