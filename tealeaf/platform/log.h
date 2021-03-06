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
 * along with the Game Closure SDK.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef PLATFORM_LOG_H
#define PLATFORM_LOG_H

#ifdef __cplusplus
extern "C" {
#endif

void _LOG(const char *f, ...);

#if (__OBJC__) == 1
void _NSLOG(NSString *f, ...);
#endif

void LoggerSetDebugger(void *debugger);

#ifdef __cplusplus
}
#endif

#ifndef RELEASE
#define LOG _LOG
#define NSLOG _NSLOG
#else
#define LOG (void)sizeof
#define NSLOG (void)sizeof
#endif

#define LOG_FUNCTION_CALLS 0
#if LOG_FUNCTION_CALLS
#define LOGFN LOG
#define NSLOGFN NSLOG
#else
#define LOGFN (void)sizeof
#define NSLOGFN (void)sizeof
#endif

#endif // PLATFORM_LOG_H
