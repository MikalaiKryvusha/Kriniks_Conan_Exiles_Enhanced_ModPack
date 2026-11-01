import json, sys
# Kismet bytecode of one function (UAssetAPI JSON) -> compact readable pseudo-code lines.
path, fname = sys.argv[1], sys.argv[2]
j = json.load(open(path, encoding='utf-8'))
imports, exports = j.get('Imports', []), j['Exports']

def objname(idx):
    if isinstance(idx, dict): idx = idx.get('Index', 0)
    if not isinstance(idx, int) or idx == 0: return 'null'
    if idx < 0:
        im = imports[-idx - 1]; return str(im.get('ObjectName'))
    return str(exports[idx - 1].get('ObjectName'))

def prop(p):
    if isinstance(p, dict):
        for k in ('Path', 'New', 'Old'):
            v = p.get(k)
            if isinstance(v, dict) and v.get('Path'):
                return '.'.join(str(x) for x in v['Path'])
            if isinstance(v, list): return '.'.join(str(x) for x in v)
        if 'ResolvedOwner' in p: return objname(p['ResolvedOwner']) + '?'
    return str(p)

SKIP = {'$type'}
def ex(e):
    if not isinstance(e, dict): return repr(e)
    t = e.get('$type', '').split('.')[-1].split(',')[0].replace('EX_', '')
    if t in ('LocalVariable', 'InstanceVariable', 'LocalOutVariable', 'DefaultVariable', 'ClassSparseDataVariable'):
        return ('self.' if t == 'InstanceVariable' else '') + prop(e.get('Variable'))
    if t in ('FinalFunction', 'VirtualFunction', 'LocalFinalFunction', 'LocalVirtualFunction', 'CallMath'):
        fn = objname(e.get('StackNode')) if 'StackNode' in e else str(e.get('VirtualFunctionName'))
        return f"{fn}({', '.join(ex(p) for p in e.get('Parameters', []))})"
    if t == 'Context' or t == 'Context_FailSilent':
        return f"{ex(e.get('ObjectExpression'))}->{ex(e.get('ContextExpression'))}"
    if t in ('Let', 'LetObj', 'LetBool', 'LetWeakObjPtr', 'LetDelegate', 'LetValueOnPersistentFrame'):
        lhs = e.get('Variable') or e.get('VariableExpression')
        return f"{ex(lhs) if isinstance(lhs, dict) and '$type' in lhs else prop(lhs)} = {ex(e.get('Expression') or e.get('AssignmentExpression'))}"
    if t in ('IntConst', 'FloatConst', 'DoubleConst', 'ByteConst', 'StringConst', 'NameConst', 'UnicodeStringConst', 'Int64Const'):
        return str(e.get('Value'))
    if t in ('True', 'False', 'Self', 'NoObject', 'Nothing', 'IntZero', 'IntOne'):
        return t
    if t == 'JumpIfNot':
        return f"if not ({ex(e.get('BooleanExpression'))}) goto {e.get('CodeOffset')}"
    if t == 'Jump': return f"goto {e.get('CodeOffset')}"
    if t in ('PopExecutionFlowIfNot',): return f"if not ({ex(e.get('BooleanExpression'))}) pop"
    if t == 'Return': return f"return {ex(e.get('ReturnExpression'))}"
    if t == 'StructMemberContext':
        return f"{ex(e.get('StructExpression'))}.{prop(e.get('StructMemberExpression'))}"
    if t in ('ObjectConst',): return objname(e.get('Value'))
    if t in ('DynamicCast', 'MetaCast', 'InterfaceToObjCast', 'ObjToInterfaceCast', 'CrossInterfaceCast', 'Cast', 'PrimitiveCast'):
        return f"cast<{objname(e.get('ClassPtr'))}>({ex(e.get('Target') or e.get('Expression'))})"
    parts = []
    for k, v in e.items():
        if k in SKIP: continue
        if isinstance(v, dict) and '$type' in v: parts.append(f"{k}={ex(v)}")
        elif isinstance(v, list) and v and isinstance(v[0], dict) and '$type' in v[0]: parts.append(f"{k}=[{', '.join(ex(x) for x in v)}]")
        elif isinstance(v, (int, float, str)) and k not in ('Tag',): parts.append(f"{k}={v}")
    return f"{t}{{{'; '.join(parts)}}}"

if fname.endswith('.json'):
    raw = open(fname, 'rb').read()
    bc = json.loads(raw.decode('utf-16') if raw[:2] in (b'\xff\xfe', b'\xfe\xff') else raw.decode('utf-8-sig'))
    for i, s in enumerate(bc):
        print(f"{i:4d} {ex(s)}"[:500])
    sys.exit(0)
for e in exports:
    if e.get('ObjectName') == fname and 'ScriptBytecode' in e:
        bc = e['ScriptBytecode'] or []
        print(f"== {fname}: {len(bc)} statements")
        for i, s in enumerate(bc):
            print(f"{i:4d} {ex(s)}"[:400])
        break
else:
    print('not found; functions with names like it:', [x.get('ObjectName') for x in exports if fname.lower() in str(x.get('ObjectName')).lower()][:20])
