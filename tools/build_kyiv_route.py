"""Build a playable Kyiv ring; station order/tariff distances are sourced, drawing is illustrative."""
from pathlib import Path
import json
import math

ROOT = Path(__file__).resolve().parents[1]
SOURCE = 'https://github.com/panichev-oleg/kce/blob/main/src/helpers/__fixtures__/internal_direction_1_date_2026-03-13.txt'
# Published tariff distances; XY are hand-drawn illustration, NOT survey coordinates.
STOPS = [
 ('sviatoshyn','Святошин',0,[-8,0]),
 ('borshchahivka','Борщагівка',2.1,[-8,-2]),
 ('kyiv_volynskyi','Київ-Волинський',5.9,[-6,-4]),
 ('karavaievi_dachi','Караваєві Дачі',9.1,[-3.5,-3]),
 ('kyiv_pasazhyrskyi','Вокзальна',12,[-1,-2]),
 ('protasiv_yar','Протасів Яр',14,[0,-3.5]),
 ('kyiv_demiiivskyi','Київ-Деміївський',17.2,[2,-5]),
 ('vydubychi','Видубичі',18.9,[4,-5.5]),
 ('berezniaky','Березняки',22.8,[7,-4]),
 ('darnytsia','Дарниця',25.8,[10,-2]),
 ('rusanivka','Русанівка',28.4,[8,-.5]),
 ('livoberezhna','Лівобережна',30,[7,1]),
 ('mykilska_slobidka','Микільська Слобідка',31.1,[6.8,2.5]),
 ('voskresenka','Воскресенка',33.4,[7.5,4.5]),
 ('troieshchyna_2','Райдужний',34,[6,5.5]),
 ('pochaina','Почайна',39.1,[1,6]),
 ('kurenivka','Куренівка',40.5,[-1,6.4]),
 ('priorka','Пріорка',42.4,[-3,5.4]),
 ('syrets','Сирець',45.7,[-5.5,3.6]),
 ('beresteiska','Берестейська',47.4,[-7,1.5]),
]
META = dict(verified=False, sources=[SOURCE, 'https://swrailway.gov.ua/timetable/eltrain/?gid=1&rid=480&reverse=1',
 # Renamings of 18.01.2024: Північна → Вокзальна, Троєщина-2 → Райдужний.
 'https://kyivcity.gov.ua/news/u_stolitsi_pereymenuvali_10_miskikh_obyektiv_zaliznichnogo_transportu/'],
 note='TODO_SOURCE: назви, порядок і тарифні відстані з опублікованого розкладу; геометрія і платформи ілюстративні, профіль та швидкості умовні. Не геодезична модель. TODO_SOURCE: міжколійя -5.3 м та дві бічні платформи — ілюстративне компонування, не перевірена схема станцій.')

def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=None if path.name=="geometry.json" else 2)+'\n')

def main():
    out=ROOT/'game/content/base/routes/kyiv_city_ring'
    segments=[]; lines=[]; nodes=[]; stations=[]
    # Smooth each station-to-station curve, with the exact station endpoints preserved.
    curves=[]
    for i in range(len(STOPS)):
        controls=[STOPS[(i+j)%len(STOPS)][3] for j in [-1,0,1,2]]
        pts=[]
        for sample in range(1201):
            t=sample/1200
            pts.append([.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t) for a,b,c,d in zip(*controls)])
        curves.append(pts)
    total=sum(sum(math.dist(a,b) for a,b in zip(pts,pts[1:])) for pts in curves)
    scale=49500/total
    chainage=0
    for i,(sid,name,km,xy) in enumerate(STOPS):
        next_id=STOPS[(i+1)%len(STOPS)][0]
        seg=f'{sid}_to_{next_id}'
        pts=[[round(x*scale,5),round(y*scale,5)] for x,y in curves[i]]
        length=sum(math.dist(a,b) for a,b in zip(pts,pts[1:]))
        segments.append(dict(id=seg,length_m=length,node_a=sid,node_b=next_id,km_at_a=chainage/1000,electrification='ac_25kv',grades=[dict(at_m=0,permille=0)],speed_limits=[dict(from_m=0,to_m=length,speed_kmh=70)]))
        prev=STOPS[(i-1)%len(STOPS)][0]
        nodes.append(dict(id=sid,kind='joint',ends=[dict(segment=f'{prev}_to_{sid}',end='b'),dict(segment=seg,end='a')]))
        lines.append(dict(segment=seg,points=pts))
        stations.append(dict(id=sid,name_uk=name,kind='station',platforms=[dict(id=sid+'_p1',segment=seg,from_m=20,to_m=260,side='right')]))
        chainage+=length
    write(out/'route.json',dict(id='kyiv_city_ring',name_uk='Київська кільцева · 20 зупинок',description_uk='Повне кільце 49,5 км. Ілюстративна геометрія, справжні назви та порядок станцій.',meta=META,electrification='ac_25kv',track_graph='track_graph.json',geometry='geometry.json',stations='stations.json',visual=dict(parallel_track_offset_m=-5.3)))
    write(out/'track_graph.json',dict(meta=META,segments=segments,nodes=nodes))
    write(out/'geometry.json',dict(meta=META,crs='local_m',polylines=lines,map_features=[dict(kind='river',label_uk='Дніпро',points=[[x*scale,y*scale] for x,y in [[4.5,9],[4,6],[4.5,2],[4,-1],[4.5,-3],[6,-7],[7,-10]]])]))
    write(out/'stations.json',dict(meta=META,stations=stations))
    sc=json.loads((ROOT/'game/content/base/scenarios/polygon_free_drive.json').read_text())
    sc.update(id='kyiv_city_free_drive',name_uk='Київ: повне кільце · готовий поїзд',description_uk='20 справжніх станцій, старт з Київ-Пасажирського.',route='kyiv_city_ring',meta=META,switches={})
    sc['start'].update(segment='kyiv_pasazhyrskyi_to_protasiv_yar',offset_m=245)
    write(ROOT/'game/content/base/scenarios/kyiv_city_free_drive.json',sc)
    print(f'Built {len(stations)} stations, {chainage:.3f} m, illustrative geometry')

if __name__=='__main__':
    main()
