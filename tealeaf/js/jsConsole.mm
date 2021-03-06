/* @license
 * This file is part of the Game Closure SDK.
 *
 * The Game Closure SDK is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 
 * The Game Closure SDK is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 
 * You should have received a copy of the GNU General Public License
 * along with the Game Closure SDK.	 If not, see <http://www.gnu.org/licenses/>.
 */

#import "js/jsConsole.h"

JSAG_MEMBER_BEGIN(log, 1)
{
	JSAG_ARG_CSTR(text);

	LOG("%s", text);
}
JSAG_MEMBER_END

JSAG_OBJECT_START(console)
JSAG_OBJECT_MEMBER(log)
JSAG_OBJECT_END


@implementation jsConsole

+ (void) addToRuntime:(js_core *)js {
	JSAG_OBJECT_ATTACH(js.cx, js.native, console);
}

+ (void) onDestroyRuntime {
	
}

@end
