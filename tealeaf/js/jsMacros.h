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

#ifndef JS_MACROS_H
#define JS_MACROS_H

// JSTR = JavaScript SpiderMonkey string
// NSTR = NSString Objective-C string
// CSTR = UTF8 C string

// The string created by these conversions will last until the
// function returns and does not need to be explicitly freed.

#define JSTR_TO_CSTR(cx, jstr, cstr) \
	size_t cstr ## _len = JS_GetStringEncodingLength(cx, jstr); \
	char *cstr = (char*)alloca(sizeof(char) * (cstr ## _len + 1)); \
	JS_EncodeStringToBuffer(jstr, cstr, cstr ## _len); \
	cstr[cstr ## _len] = (char)'\0';

#define JSTR_TO_CSTR_PERSIST(cx, jstr, cstr) \
	size_t cstr ## _len = JS_GetStringEncodingLength(cx, jstr); \
	char *cstr = (char*)malloc(sizeof(char) * (cstr ## _len + 1)); \
	JS_EncodeStringToBuffer(jstr, cstr, cstr ## _len); \
	cstr[cstr ## _len] = (char)'\0';

#define PERSIST_CSTR_RELEASE(cstr) \
	free(cstr);

#define STRINGIZE(x) STRINGIZE1(x)
#define STRINGIZE1(x) #x
#define AG_FILELINE __FILE__ " at line " STRINGIZE(__LINE__)

#define CSTR_TO_JSTR(cx, cstr) JS_NewStringCopyZ(cx, cstr)

#define CSTR_TO_JSVAL(cx, cstr) STRING_TO_JSVAL(CSTR_TO_JSTR(cx, cstr))

#if (__OBJC__) == 1

#define JSTR_TO_NSTR(cx, jstr, nstr) \
	size_t nstr ## _len; \
	jschar *nstr ## _jc = (jschar*)JS_GetStringCharsZAndLength(cx, jstr, &nstr ## _len); \
	NSString *nstr = [[[NSString alloc] initWithCharactersNoCopy:nstr ## _jc length:nstr ## _len freeWhenDone:NO] autorelease];

inline JSString *JSStringFromNSString(JSContext *cx, NSString *nstr) {
	int chars = (int)[nstr length];
	unichar *buffer;

	if (chars <= 0) {
		return JSVAL_TO_STRING(JS_GetEmptyStringValue(cx));
	} else {
		buffer = (unichar*)JS_malloc(cx, chars * sizeof(unichar));
		[nstr getCharacters:buffer range:NSMakeRange(0, chars)];

		JSString *rval = JS_NewUCString(cx, buffer, chars);
		if (!rval) {
			JS_free(cx, buffer);
		}
		return rval;
	}
}

#define NSTR_TO_JSTR(cx, nstr) JSStringFromNSString(cx, nstr)

#define NSTR_TO_JSVAL(cx, nstr) STRING_TO_JSVAL(NSTR_TO_JSTR(cx, nstr))

#define JSVAL_TO_NSTR(cx, val, nstr) \
	JSString *nstr ## _jstr = JSVAL_TO_STRING(val); \
	JSTR_TO_NSTR(cx, nstr ## _jstr, nstr);

#endif

#define JSVAL_TO_CSTR(cx, val, cstr) \
	JSString *cstr ## _jstr = JSVAL_TO_STRING(val); \
	JSTR_TO_CSTR(cx, cstr ## _jstr, cstr);

// WTF Mozilla is it really that hard to keep backwards compatibility? -cat
#define JSVAL_IS_OBJECT(v) !JSVAL_IS_PRIMITIVE(v)


// TODO: Needed?
//#ifndef __UNUSED
//#define __UNUSED __attribute__((unused))
//#endif

#define PROPERTY_FLAGS JSPROP_ENUMERATE | JSPROP_READONLY | JSPROP_PERMANENT
#define FUNCTION_FLAGS JSPROP_READONLY | JSPROP_PERMANENT
#define JS_MUTABLE_FUNCTION_FLAGS JSPROP_PERMANENT




// Engine-agnosticizer

#define JSAG_OBJECT JSObject
#define JSAG_VALUE jsval

#define JSAG_BOOL JSBool
#define JSAG_FALSE JS_FALSE
#define JSAG_TRUE JS_TRUE

// Member definitions

#define JSAG_MEMBER_BEGIN_NOARGS(jsName) \
	static const int jsag_member_ ## jsName ## _argCount = 0; \
	static JSBool jsag_member_ ## jsName (JSContext *cx, unsigned argc, jsval *vp) {

#define JSAG_MEMBER_END_NOARGS \
	return JS_TRUE; }

#define JSAG_MEMBER_BEGIN(jsName, minArgs) \
	static const int jsag_member_ ## jsName ## _argCount = minArgs; \
	static JSBool jsag_member_ ## jsName (JSContext *cx, unsigned argc, jsval *vp) { \
		static const char *JSAG_FN_NAME_STR = #jsName; { \
		if (unlikely(argc < minArgs)) { goto jsag_fail; } \
		jsval *argv = JS_ARGV(cx, vp); \
		unsigned argsLeft = argc; \
		JS_BeginRequest(cx);

// JS function arguments

#define JSAG_THIS \
	JS_THIS_OBJECT(cx, vp)

#define JSAG_ARG_SKIP \
	--argsLeft; ++argv;

#define JSAG_ARG_JSVAL(name) \
	jsval name = *argv; \
	--argsLeft; ++argv;

#define JSAG_ARG_INT32(name) \
	int32_t name; \
	if (unlikely(JS_FALSE == JS_ValueToECMAInt32(cx, *argv, &name))) { goto jsag_fail; } \
	--argsLeft; ++argv;

#define JSAG_ARG_INT32_OPTIONAL(name, default) \
	int32_t name = default; \
	if (argsLeft > 0) { \
		if (unlikely(JS_FALSE == JS_ValueToECMAInt32(cx, *argv, &name))) { goto jsag_fail; } \
		--argsLeft; ++argv; \
	}

#define JSAG_ARG_JSTR(name) \
	JSString *name = JS_ValueToString(cx, *argv); \
	if (unlikely(!name)) { goto jsag_fail; } \
	--argsLeft; ++argv;

#define JSAG_ARG_NSTR_OPTIONAL(name, default) \
	NSString *name = default; \
	if (argsLeft > 0) { \
		JSString *name ## _jstr = JS_ValueToString(cx, *argv); \
		if (unlikely(!name)) { goto jsag_fail; } \
		--argsLeft; ++argv; \
		JSTR_TO_NSTR(cx, name ## _jstr, name ## _tmp); \
		name = name ## _tmp; \
	}

#define JSAG_ARG_IS_STRING JSVAL_IS_STRING(*argv)

#define JSAG_ARG_IS_ARRAY ( JSVAL_IS_OBJECT(*argv) && JS_IsArrayObject(cx, JSVAL_TO_OBJECT(*argv)) )

#define JSAG_ARG_CSTR(name) JSAG_ARG_JSTR(name ## _jstr); JSTR_TO_CSTR(cx, name ## _jstr, name);

#define JSAG_ARG_NSTR(name) JSAG_ARG_JSTR(name ## _jstr); JSTR_TO_NSTR(cx, name ## _jstr, name);

#define JSAG_ARG_CSTR_FIRST(name, count) \
	JSAG_ARG_JSTR(name ## _jstr); \
	char name[count] = {0}; \
	int name ## _len = (int)JS_EncodeStringToBuffer(name ## _jstr, name, count);

#define JSAG_ARG_DOUBLE(name) \
	double name; \
	if (unlikely(JS_FALSE == JS_ValueToNumber(cx, *argv, &name))) { goto jsag_fail; } \
	--argsLeft; ++argv;

#define JSAG_ARG_DOUBLE_OPTIONAL(name, default) \
	double name = default; \
	if (argsLeft > 0) { \
		if (unlikely(JS_FALSE == JS_ValueToNumber(cx, *argv, &name))) { goto jsag_fail; } \
		--argsLeft; ++argv; \
	}

#define JSAG_ARG_OBJECT(name) \
	JSObject *name; \
	{ jsval name ## _val = *argv; \
		if (unlikely(!JSVAL_IS_OBJECT(name ## _val))) { goto jsag_fail; } \
		name = JSVAL_TO_OBJECT(name ## _val);\
	} --argsLeft; ++argv;

// Will be NULL if not present
#define JSAG_ARG_OBJECT_OPTIONAL(name) \
	JSObject *name = NULL; \
	if (argsLeft > 0) { \
		jsval name ## _val = *argv; \
		if (unlikely(!JSVAL_IS_OBJECT(name ## _val))) { goto jsag_fail; } \
		--argsLeft; ++argv; \
		name = JSVAL_TO_OBJECT(name ## _val);\
	}

#define JSAG_ARG_ARRAY(name) \
	JSObject *name; \
	{ jsval name ## _val = *argv; \
		if (unlikely(!JSVAL_IS_OBJECT(name ## _val))) { goto jsag_fail; } \
		name = JSVAL_TO_OBJECT(name ## _val);\
		if (unlikely(!JS_IsArrayObject(cx, name))) { goto jsag_fail; } \
	} --argsLeft; ++argv;

#define JSAG_ARG_FUNCTION(name) \
	JSObject *name; \
	{ jsval name ## _val = *argv; \
		if (unlikely(!JSVAL_IS_OBJECT(name ## _val))) { goto jsag_fail; } \
		name = JSVAL_TO_OBJECT(name ## _val);\
		if (unlikely(!name || !JS_ObjectIsFunction(cx, name))) { goto jsag_fail; } \
	} --argsLeft; ++argv;

#define JSAG_ARG_BOOL(name) \
	bool name = ToBoolean(*argv); \
	--argsLeft; ++argv;

#define JSAG_RETURN_INT32(name) \
	JS_SET_RVAL(cx, vp, INT_TO_JSVAL(name));

#define JSAG_RETURN_DOUBLE(name) \
	JS_SET_RVAL(cx, vp, DOUBLE_TO_JSVAL(name));

#define JSAG_RETURN_BOOL(name) \
	JS_SET_RVAL(cx, vp, BOOLEAN_TO_JSVAL(name));

#define JSAG_RETURN_TRUE \
	JS_SET_RVAL(cx, vp, JSVAL_TRUE);

#define JSAG_RETURN_FALSE \
	JS_SET_RVAL(cx, vp, JSVAL_FALSE);

#define JSAG_RETURN_CSTR(cstr) \
	JS_SET_RVAL(cx, vp, CSTR_TO_JSVAL(cx, cstr));

#define JSAG_RETURN_NSTR(nstr) \
	JS_SET_RVAL(cx, vp, NSTR_TO_JSVAL(cx, nstr));

#define JSAG_RETURN_NULL \
	JS_SET_RVAL(cx, vp, JSVAL_NULL);

#define JSAG_RETURN_VOID \
	JS_SET_RVAL(cx, vp, JSVAL_VOID);

#define JSAG_RETURN_OBJECT(obj) \
	JS_SET_RVAL(cx, vp, OBJECT_TO_JSVAL(obj));

#define JSAG_RETURN_JSVAL(val) \
	JS_SET_RVAL(cx, vp, val);

#define JSAG_MEMBER_END \
	JS_EndRequest(cx); \
	return JS_TRUE; \
} \
jsag_fail: \
	JS_ReportError(cx, "Invalid arguments to %s", JSAG_FN_NAME_STR); \
	JS_EndRequest(cx); \
	return JS_FALSE; \
}

// Class definition

#define JSAG_CLASS_FINALIZE(className, obj) \
	static void class_ ## className ## _finalizer(JSFreeOp *fop, JSObject *obj)

#define JSAG_CLASS_IMPL(name) \
	static const JSClass name ## _class = { \
		#name, JSCLASS_HAS_PRIVATE, \
		JS_PropertyStub, JS_PropertyStub, JS_PropertyStub, JS_StrictPropertyStub, \
		JS_EnumerateStub, JS_ResolveStub, JS_ConvertStub, class_ ## name ## _finalizer, \
		JSCLASS_NO_OPTIONAL_MEMBERS \
	};

#define JSAG_CLASS_INSTANCE(name) \
	JS_NewObjectForConstructor(cx, (JSClass*)&name ## _class, vp);

#define JSAG_ADD_PROPERTY(obj, name, value) \
	JS_SetProperty(cx, obj, #name, value);

#define JSAG_GET_PRIVATE(name) \
	JS_GetPrivate(name)

#define JSAG_SET_PRIVATE(name, value) \
	JS_SetPrivate(name, value);

#define JSAG_CREATE_CLASS(obj, name) \
	JS_InitClass(cx, obj, NULL, (JSClass*)&name ## _class, jsag_member_ ## name, jsag_member_ ## name ## _argCount, NULL, (JSFunctionSpec*)jsag_ ## name ## _members, NULL, NULL);

// Object definition

#define JSAG_OBJECT_START(name) \
	static const JSFunctionSpec jsag_ ## name ## _members[] = {

#define JSAG_OBJECT_MEMBER(jsName) \
	JS_FN(#jsName, jsag_member_ ## jsName, jsag_member_ ## jsName ## _argCount, FUNCTION_FLAGS),

#define JSAG_MUTABLE_OBJECT_MEMBER(jsName) \
	JS_FN(#jsName, jsag_member_ ## jsName, jsag_member_ ## jsName ## _argCount, JS_MUTABLE_FUNCTION_FLAGS),

#define JSAG_OBJECT_MEMBER_NAMED(jsName, functionName) \
	JS_FN(#jsName, jsag_member_ ## functionName, jsag_member_ ## functionName ## _argCount, FUNCTION_FLAGS),

#define JSAG_OBJECT_END \
	JS_FS_END };

#define JSAG_OBJECT_ATTACH(cx, parent, jsClassName) { \
		JSObject *jsClassName ## _obj = JS_NewObject(cx, NULL, NULL, NULL); \
		JS_DefineProperty(cx, parent, #jsClassName, OBJECT_TO_JSVAL(jsClassName ## _obj), NULL, NULL, PROPERTY_FLAGS); \
		JS_DefineFunctions(cx, jsClassName ## _obj,  (JSFunctionSpec*)jsag_ ## jsClassName ## _members); \
	}

#define JSAG_OBJECT_ATTACH_EXISTING(cx, parent, jsClassName, existingObject) { \
		JS_DefineProperty(cx, parent, #jsClassName, OBJECT_TO_JSVAL(existingObject), NULL, NULL, PROPERTY_FLAGS); \
		JS_DefineFunctions(cx, existingObject,  (JSFunctionSpec*)jsag_ ## jsClassName ## _members); \
	}


#endif

