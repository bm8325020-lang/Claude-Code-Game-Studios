# Converte um recorte do OpenStreetMap (XML da API, bbox pequeno) em JSON no espaço do jogo (metros, x = leste,
# z = sul, origem no centro): prédios (polígono, andares, tipo) e ruas (pontos, tipo).
# Uso: python3 tools/mapa/osm_para_json.py entrada.xml saida.json
import json, math, sys, xml.etree.ElementTree as ET

raiz = ET.parse(sys.argv[1]).getroot()
b = raiz.find('bounds')
lat0 = (float(b.get('minlat')) + float(b.get('maxlat'))) / 2
lon0 = (float(b.get('minlon')) + float(b.get('maxlon'))) / 2
k_lon = math.cos(math.radians(lat0)) * 111320.0
nos = {n.get('id'): (round((float(n.get('lon')) - lon0) * k_lon, 2), round(-(float(n.get('lat')) - lat0) * 110540.0, 2)) for n in raiz.findall('node')}
predios, ruas = [], []
for w in raiz.findall('way'):
    tags = {t.get('k'): t.get('v') for t in w.findall('tag')}
    pts = [nos[n.get('ref')] for n in w.findall('nd') if n.get('ref') in nos]
    if 'building' in tags and len(pts) >= 4:
        if pts[0] == pts[-1]:
            pts = pts[:-1]
        andares = tags.get('building:levels')
        altura = tags.get('height')
        predios.append({'p': pts, 'tipo': tags['building'], 'andares': float(andares) if andares and andares.replace('.', '').isdigit() else 0,
                        'altura': float(altura.split()[0]) if altura and altura.split()[0].replace('.', '').isdigit() else 0,
                        'nome': tags.get('name', ''), 'uso': tags.get('amenity', tags.get('shop', ''))})
    elif 'highway' in tags and len(pts) >= 2:
        ruas.append({'p': pts, 'tipo': tags['highway']})
json.dump({'origem': [lat0, lon0], 'predios': predios, 'ruas': ruas}, open(sys.argv[2], 'w'))
print(len(predios), 'prédios,', len(ruas), 'ruas')
