"""Compositor de interiores com regras (05/11, RAVEN CREEK; prompt do dono: "nada de móvel jogado").

Python puro (sem bpy): o gerador de casas (casas_us.py) chama `compoe(tipo, comodo, rng)` e recebe a lista de móveis
com posição e giro; quem constrói é ele. Teste: python3 tools/blender/test_interiores.py

Cômodo: retângulo interno (x0, y0, x1, y1) (já sem a espessura da parede), portas e janelas por parede.
Paredes: 0 = y0 (frente), 1 = x1, 2 = y1 (fundo), 3 = x0. Abertura: (parede, t, largura) com t = metros ao longo da
parede a partir do canto de menor coordenada. Janela: (parede, t, largura, base).
Giro (Blender): com ang = 0 a frente do móvel olha para -Y (encosto em +Y), como sofa()/cama()/vaso() em ruinas.py.

Regras: cada tipo de cômodo tem uma âncora (parede da TV, cabeceira, parede da pia...) e conjuntos (sofá + mesa de
centro + TV; cama + criados; bancada + fogão + pia + geladeira; vaso + pia + banheira). Nada encosta na frente de
porta (zona livre ZONA_PORTA), móvel alto não tapa janela, cada móvel tem folga na frente, e tem que dar para chegar
na frente de cada móvel principal saindo da porta (grade de PASSO_GRADE, corpo do jogador RAIO_JOGADOR).
"""
import math

ZONA_PORTA = 1.0       # m livres na frente de cada porta (abre e passa)
FOLGA_PAREDE = 0.02
PASSO_GRADE = 0.15
RAIO_JOGADOR = 0.3

# tipo: (largura em X, profundidade em Y, altura, folga na frente, sem colisão?)
MOVEIS = {
    "sofa": (2.0, 0.9, 0.85, 0.4, False), "poltrona": (0.85, 0.85, 0.85, 0.4, False),
    "mesa_centro": (1.1, 0.6, 0.45, 0.0, False), "tv": (1.4, 0.45, 1.1, 0.9, False),
    "estante": (1.2, 0.4, 1.9, 0.6, False), "abajur": (0.35, 0.35, 1.5, 0.0, False),
    "tapete": (2.4, 1.7, 0.01, 0.0, True),
    "cama": (1.6, 2.1, 0.6, 0.6, False), "cama_solteiro": (1.0, 2.0, 0.6, 0.6, False),
    "criado": (0.45, 0.4, 0.55, 0.3, False), "guarda_roupa": (1.2, 0.6, 2.0, 0.7, False),
    "comoda": (1.0, 0.5, 0.9, 0.6, False), "tapete_quarto": (1.4, 1.0, 0.01, 0.0, True),
    "balcao": (0.8, 0.62, 0.9, 1.0, False), "pia": (1.0, 0.62, 0.9, 1.0, False), "fogao": (0.76, 0.65, 0.9, 1.0, False),
    "geladeira": (0.8, 0.75, 1.8, 1.0, False), "mesa": (1.4, 0.9, 0.75, 0.0, False), "cadeira": (0.45, 0.45, 0.9, 0.0, False),
    "vaso": (0.4, 0.68, 0.8, 0.5, False), "pia_banheiro": (0.6, 0.48, 0.85, 0.6, False),
    "banheira": (0.75, 1.6, 0.6, 0.5, False), "chuveiro": (0.9, 0.9, 2.0, 0.5, False),
    "lavadora": (0.65, 0.65, 0.9, 0.8, False), "secadora": (0.65, 0.65, 0.9, 0.8, False),
    "bancada": (1.8, 0.7, 0.95, 0.8, False), "prateleira": (1.2, 0.45, 1.8, 0.6, False),
    "escrivaninha": (1.4, 0.7, 0.75, 0.7, False), "aparador": (1.4, 0.45, 0.85, 0.5, False),
}
PRINCIPAIS = {"sofa", "tv", "cama", "cama_solteiro", "guarda_roupa", "pia", "fogao", "geladeira", "vaso", "pia_banheiro",
              "lavadora", "bancada", "escrivaninha", "estante"}


class Comodo:
    def __init__(self, x0, y0, x1, y1, portas=(), janelas=()):
        self.x0, self.y0, self.x1, self.y1 = x0, y0, x1, y1
        self.portas = list(portas)
        self.janelas = list(janelas)

    def comp(self, p):
        return (self.x1 - self.x0) if p % 2 == 0 else (self.y1 - self.y0)

    def ponto(self, p, t, d=0.0):
        """Ponto a t da parede p, d para dentro."""
        if p == 0:
            return (self.x0 + t, self.y0 + d)
        if p == 1:
            return (self.x1 - d, self.y0 + t)
        if p == 2:
            return (self.x0 + t, self.y1 - d)
        return (self.x0 + d, self.y0 + t)

    @staticmethod
    def frente(p):
        """Vetor para dentro do cômodo a partir da parede p."""
        return [(0, 1), (-1, 0), (0, -1), (1, 0)][p]


def ang_de(f):
    return math.atan2(f[0], -f[1])


def caixa_de(x, y, ang, larg, prof):
    """Retângulo alinhado (o giro é sempre múltiplo de 90 graus aqui)."""
    q = round(ang / (math.pi / 2)) % 2
    w, d = (larg, prof) if q == 0 else (prof, larg)
    return (x - w / 2, y - d / 2, x + w / 2, y + d / 2)


def cruza(a, b, margem=0.0):
    return a[0] < b[2] - margem and b[0] < a[2] - margem and a[1] < b[3] - margem and b[1] < a[3] - margem


class Compositor:
    def __init__(self, c, rng):
        self.c = c
        self.rng = rng
        self.itens = []          # dicts: tipo, x, y, ang, caixa, alt, livre (só enfeite)
        self.proibido = []       # zonas das portas
        for (p, t, lg) in c.portas:
            a = c.ponto(p, t - lg / 2 - 0.1)
            b = c.ponto(p, t + lg / 2 + 0.1, ZONA_PORTA)
            self.proibido.append((min(a[0], b[0]), min(a[1], b[1]), max(a[0], b[0]), max(a[1], b[1])))

    # --- checagens ---
    def cabe(self, cx, alt, ocupa_janela=True, livre=False):
        c = self.c
        if cx[0] < c.x0 + FOLGA_PAREDE - 1e-6 or cx[1] < c.y0 + FOLGA_PAREDE - 1e-6 or \
           cx[2] > c.x1 - FOLGA_PAREDE + 1e-6 or cx[3] > c.y1 - FOLGA_PAREDE + 1e-6:
            return False
        if livre:
            return True
        if any(cruza(cx, z) for z in self.proibido):
            return False
        if any(cruza(cx, i["caixa"], 0.005) or cruza(cx, i["folga"], 0.005) for i in self.itens if not i["livre"]):
            return False
        if ocupa_janela and alt > 1.0:
            for (p, t, lg, base) in c.janelas:
                a = c.ponto(p, t - lg / 2)
                b = c.ponto(p, t + lg / 2, 0.6)
                z = (min(a[0], b[0]), min(a[1], b[1]), max(a[0], b[0]), max(a[1], b[1]))
                if alt > base and cruza(cx, z):
                    return False
        return True

    def poe(self, tipo, x, y, ang, livre=None, nome=None):
        larg, prof, alt, folga, sem = MOVEIS[tipo]
        livre = sem if livre is None else livre
        cx = caixa_de(x, y, ang, larg, prof)
        fx, fy = math.sin(ang), -math.cos(ang)  # para onde a frente olha
        fz = (cx[0] + fx * folga if fx < 0 else cx[0], cx[1] + fy * folga if fy < 0 else cx[1],
              cx[2] + fx * folga if fx > 0 else cx[2], cx[3] + fy * folga if fy > 0 else cx[3])
        fz = (min(fz[0], cx[0]), min(fz[1], cx[1]), max(fz[2], cx[2]), max(fz[3], cx[3]))
        if not self.cabe(cx, alt, livre=livre):
            return None
        if not livre and folga > 0:  # a folga da frente não pode cair em móvel já posto nem fora do cômodo
            fr = self._so_frente(cx, fz)
            if fr and (any(cruza(fr, i["caixa"], 0.005) for i in self.itens if not i["livre"]) or not self._dentro(fr)):
                return None
        it = {"tipo": tipo, "nome": nome or tipo, "x": x, "y": y, "ang": ang, "caixa": cx, "folga": self._so_frente(cx, fz) or cx,
              "alt": alt, "livre": livre}
        self.itens.append(it)
        if not livre and not self.acessivel()[0]:  # fechou o caminho da porta até algum móvel ou porta: não entra
            self.itens.pop()
            return None
        return it

    @staticmethod
    def _so_frente(cx, fz):
        if fz == cx:
            return None
        if fz[0] < cx[0]:
            return (fz[0], cx[1], cx[0], cx[3])
        if fz[2] > cx[2]:
            return (cx[2], cx[1], fz[2], cx[3])
        if fz[1] < cx[1]:
            return (cx[0], fz[1], cx[2], cx[1])
        return (cx[0], cx[3], cx[2], fz[3])

    def _dentro(self, r):
        c = self.c
        return r[0] >= c.x0 - 1e-6 and r[1] >= c.y0 - 1e-6 and r[2] <= c.x1 + 1e-6 and r[3] <= c.y1 + 1e-6

    def encosta(self, tipo, p, t, nome=None):
        """Móvel de costas para a parede p, centrado em t."""
        larg, prof = MOVEIS[tipo][0], MOVEIS[tipo][1]
        x, y = self.c.ponto(p, t, prof / 2 + FOLGA_PAREDE)
        return self.poe(tipo, x, y, ang_de(Comodo.frente(p)), nome=nome)

    def trechos(self, p):
        """Trechos livres da parede p (fora das portas), [(t0, t1)]."""
        cortes = sorted((t - lg / 2 - 0.1, t + lg / 2 + 0.1) for (q, t, lg) in self.c.portas if q == p)
        out, t = [], 0.0
        for (a, b) in cortes:
            if a > t:
                out.append((t, a))
            t = max(t, b)
        if t < self.c.comp(p):
            out.append((t, self.c.comp(p)))
        return out

    def ao_longo(self, tipo, p, nome=None, preferir=None):
        """Tenta pôr encostado na parede p, varrendo os trechos livres (do preferido para fora)."""
        larg = MOVEIS[tipo][0]
        cands = []
        for (a, b) in self.trechos(p):
            t = a + larg / 2 + 0.05
            while t <= b - larg / 2 - 0.05 + 1e-6:
                cands.append(t)
                t += 0.1
        if preferir is not None:
            cands.sort(key=lambda t: abs(t - preferir))
        else:
            self.rng.shuffle(cands)
        for t in cands:
            it = self.encosta(tipo, p, t, nome)
            if it:
                return it
        return None

    # --- caminho: da porta até a frente de cada móvel principal ---
    def acessivel(self):
        c = self.c
        nx = int((c.x1 - c.x0) / PASSO_GRADE) + 1
        ny = int((c.y1 - c.y0) / PASSO_GRADE) + 1
        bloq = [i["caixa"] for i in self.itens if not i["livre"]]
        def livre(ix, iy):
            x, y = c.x0 + ix * PASSO_GRADE, c.y0 + iy * PASSO_GRADE
            if x < c.x0 + RAIO_JOGADOR - 0.01 or x > c.x1 - RAIO_JOGADOR + 0.01 or y < c.y0 + RAIO_JOGADOR - 0.01 or y > c.y1 - RAIO_JOGADOR + 0.01:
                return False
            r = (x - RAIO_JOGADOR, y - RAIO_JOGADOR, x + RAIO_JOGADOR, y + RAIO_JOGADOR)
            return not any(cruza(r, b) for b in bloq)
        if not c.portas:
            return True, []
        p, t, lg = c.portas[0]
        sx, sy = c.ponto(p, t, RAIO_JOGADOR + 0.05)
        ini = (int(round((sx - c.x0) / PASSO_GRADE)), int(round((sy - c.y0) / PASSO_GRADE)))
        perto = [(ini[0] + a, ini[1] + b) for a in (0, -1, 1, -2, 2) for b in (0, -1, 1, -2, 2)]
        vis = {next((q for q in perto if livre(*q)), ini)}
        vis = {q for q in vis if livre(*q)}
        fila = list(vis)
        while fila:
            ix, iy = fila.pop()
            for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (ix + dx, iy + dy)
                if 0 <= q[0] < nx and 0 <= q[1] < ny and q not in vis and livre(*q):
                    vis.add(q)
                    fila.append(q)
        falta = []
        alc = RAIO_JOGADOR + 0.25  # chega no móvel por qualquer lado livre (sofá que flutua: por trás ou pelo lado)
        pontos = [(c.x0 + ix * PASSO_GRADE, c.y0 + iy * PASSO_GRADE) for (ix, iy) in vis]
        for i in self.itens:
            if i["tipo"] not in PRINCIPAIS:
                continue
            cx = i["caixa"]
            if not any(cx[0] - alc <= x <= cx[2] + alc and cx[1] - alc <= y <= cx[3] + alc for (x, y) in pontos):
                falta.append(i["nome"])
        for (p2, t2, lg2) in c.portas[1:]:  # todas as portas ligadas
            sx, sy = c.ponto(p2, t2, RAIO_JOGADOR + 0.05)
            q = (int(round((sx - c.x0) / PASSO_GRADE)), int(round((sy - c.y0) / PASSO_GRADE)))
            if not any((q[0] + a, q[1] + b) in vis for a in (-1, 0, 1) for b in (-1, 0, 1)):
                falta.append("porta_%d" % p2)
        return not falta, falta

    def valida(self):
        """Lista de problemas (vazia = ok)."""
        probs = []
        duros = [i for i in self.itens if not i["livre"]]
        for k, a in enumerate(duros):
            if not self._dentro(a["caixa"]):
                probs.append("fora: " + a["nome"])
            for b in duros[k + 1:]:
                if cruza(a["caixa"], b["caixa"], 0.005):
                    probs.append("bate: %s x %s" % (a["nome"], b["nome"]))
            if any(cruza(a["caixa"], z) for z in self.proibido):
                probs.append("na porta: " + a["nome"])
        ok, falta = self.acessivel()
        probs += ["sem caminho: " + f for f in falta]
        return probs

    # --- parede que mais serve ---
    def parede_maior(self, evita=()):
        ps = [p for p in range(4) if p not in evita]
        return max(ps, key=lambda p: (max([b - a for (a, b) in self.trechos(p)] or [0]), self.rng.random()))

    def parede_da_porta(self):
        return self.c.portas[0][0] if self.c.portas else 0


# ---------------- regras por cômodo ----------------

def _sala(k):
    c = k.c
    porta = k.parede_da_porta()
    tvp = k.parede_maior(evita=(porta,)) if k.rng.random() < 0.8 else k.parede_maior()
    sofp = (tvp + 2) % 4
    tv = k.ao_longo("tv", tvp, preferir=c.comp(tvp) / 2)
    if not tv:
        return
    f = Comodo.frente(tvp)
    prof = c.comp((tvp + 1) % 4)                  # distância entre a parede da TV e a oposta
    d_sofa = min(max(prof - 0.47, 2.9), 3.4)     # encosta na parede de trás se a sala for rasa; senão flutua
    cx, cy = tv["x"] + f[0] * (d_sofa - MOVEIS["tv"][1] / 2), tv["y"] + f[1] * (d_sofa - MOVEIS["tv"][1] / 2)
    sofa = None
    for dt in (0.0, 0.3, -0.3, 0.6, -0.6):        # sofa virado para a TV
        lado = (-f[1], f[0])
        sofa = k.poe("sofa", cx + lado[0] * dt, cy + lado[1] * dt, ang_de((-f[0], -f[1])))
        if sofa:
            break
    if not sofa:
        sofa = k.ao_longo("sofa", sofp)
        if not sofa:
            return
    sx, sy = sofa["x"], sofa["y"]
    mx, my = sx - f[0] * 1.17, sy - f[1] * 1.17        # mesa de centro a 42 cm da frente do sofá
    k.poe("mesa_centro", mx, my, sofa["ang"])
    k.poe("tapete", mx, my, sofa["ang"])
    lado = (-f[1], f[0])
    for s in (1, -1):                                  # poltrona do lado da mesa, virada para ela
        px, py = mx + lado[0] * s * 1.45, my + lado[1] * s * 1.45
        if k.poe("poltrona", px, py, ang_de((-lado[0] * s, -lado[1] * s))):
            break
    for s in (1, -1):                                  # abajur de pé do lado do sofá
        if k.poe("abajur", sx + lado[0] * s * 1.25, sy + lado[1] * s * 1.25, 0.0):
            break
    for p in sorted(range(4), key=lambda q: q in (tvp, porta)):  # estante numa parede livre
        if k.ao_longo("estante", p):
            break


def _quarto(k, solteiro=False):
    c = k.c
    porta = k.parede_da_porta()
    cab = (porta + 2) % 4 if k.rng.random() < 0.75 else (porta + (1 if k.rng.random() < 0.5 else 3)) % 4
    tipo = "cama_solteiro" if solteiro else "cama"
    cama = None
    for p in (cab, (cab + 1) % 4, (cab + 3) % 4):
        cama = k.ao_longo(tipo, p, preferir=c.comp(p) / 2)
        if cama:
            cab = p
            break
    if not cama:
        return
    f = Comodo.frente(cab)
    lc = MOVEIS[tipo][0]
    t_cama = (cama["x"] - c.x0) if cab % 2 == 0 else (cama["y"] - c.y0)
    for s in (1, -1):                                  # criados dos dois lados da cabeceira
        k.encosta("criado", cab, t_cama + s * (lc / 2 + 0.28))
    pe_x, pe_y = cama["x"] + f[0] * (MOVEIS[tipo][1] / 2 + 0.6), cama["y"] + f[1] * (MOVEIS[tipo][1] / 2 + 0.6)
    k.poe("tapete_quarto", pe_x, pe_y, cama["ang"])
    for p in sorted((q for q in range(4) if q != cab), key=lambda q: (q == porta, k.rng.random())):
        if k.ao_longo("guarda_roupa", p):
            break
    for p in sorted((q for q in range(4) if q != cab), key=lambda q: k.rng.random()):
        if k.ao_longo("comoda", p):
            break


def _cozinha(k):
    c = k.c
    jan = [j for j in c.janelas if j[3] >= 0.85]
    porta = k.parede_da_porta()
    pp = jan[0][0] if jan and jan[0][0] != porta else k.parede_maior(evita=(porta,))
    tj = jan[0][1] if jan and jan[0][0] == pp else None
    pia = k.ao_longo("pia", pp, preferir=tj if tj is not None else c.comp(pp) / 2)
    if not pia:
        return
    tp = (pia["x"] - c.x0) if pp % 2 == 0 else (pia["y"] - c.y0)
    # bancada para os dois lados; o fogão no meio de um lado; a geladeira na ponta
    for s in (1, -1):
        t = tp + s * (MOVEIS["pia"][0] / 2)
        seq = ["balcao", "fogao", "balcao"] if s == 1 else ["balcao", "geladeira"]
        for tipo in seq:
            w = MOVEIS[tipo][0]
            it = k.encosta(tipo, pp, t + s * w / 2)
            if not it:
                break
            t += s * w
    tem = {i["tipo"] for i in k.itens}
    for tipo in ("fogao", "geladeira"):  # não coube na linha: na mesma parede ou na do lado (cozinha em L)
        if tipo not in tem:
            for p in (pp, (pp + 1) % 4, (pp + 3) % 4):
                if k.ao_longo(tipo, p):
                    break
    mx, my = (c.x0 + c.x1) / 2, (c.y0 + c.y1) / 2  # mesa no meio, longe da bancada
    f = Comodo.frente(pp)
    mx += f[0] * 0.4
    my += f[1] * 0.4
    mesa = k.poe("mesa", mx, my, 0.0 if pp % 2 == 0 else math.pi / 2)
    if mesa:
        cx = mesa["caixa"]
        for (dx, dy, a) in ((0, 1, 0.0), (0, -1, math.pi), (1, 0, -math.pi / 2), (-1, 0, math.pi / 2)):
            px = mx + dx * ((cx[2] - cx[0]) / 2 + 0.3)
            py = my + dy * ((cx[3] - cx[1]) / 2 + 0.3)
            k.poe("cadeira", px, py, a)
    else:
        k.ao_longo("aparador", (pp + 2) % 4)


def _banheiro(k):
    c = k.c
    porta = k.parede_da_porta()
    # banheira numa parede sem porta, de preferência a curta (ocupa a largura do banheiro)
    p_ban = min((q for q in range(4) if q != porta), key=lambda q: (c.comp(q) < 1.6, c.comp(q)))
    larg_ban = MOVEIS["banheira"][1]
    ban = None
    if c.comp(p_ban) >= larg_ban - 0.05:
        f = Comodo.frente(p_ban)
        for t in (c.comp(p_ban) / 2, larg_ban / 2 + 0.02, c.comp(p_ban) - larg_ban / 2 - 0.02):
            x, y = c.ponto(p_ban, t, MOVEIS["banheira"][0] / 2 + FOLGA_PAREDE)
            ban = k.poe("banheira", x, y, ang_de(f) + math.pi / 2)  # deitada ao longo da parede
            if ban:
                break
    if not ban:
        for p in range(4):
            if k.ao_longo("chuveiro", p):
                break
    for p in sorted(range(4), key=lambda q: (q == porta, q == p_ban, k.rng.random())):
        if k.ao_longo("vaso", p):
            break
    for p in sorted(range(4), key=lambda q: (q == p_ban, k.rng.random())):
        if k.ao_longo("pia_banheiro", p):
            break


def _lavanderia(k):
    p = k.parede_maior(evita=(k.parede_da_porta(),))
    a = k.ao_longo("lavadora", p)
    if a:
        t = (a["x"] - k.c.x0) if p % 2 == 0 else (a["y"] - k.c.y0)
        if not k.encosta("secadora", p, t + 0.67):
            k.encosta("secadora", p, t - 0.67)
    k.ao_longo("prateleira", (p + 1) % 4) or k.ao_longo("prateleira", (p + 3) % 4)


def _garagem(k):
    porta = k.parede_da_porta()
    k.ao_longo("bancada", (porta + 2) % 4)
    for p in ((porta + 1) % 4, (porta + 3) % 4):
        k.ao_longo("prateleira", p)


def _escritorio(k):
    porta = k.parede_da_porta()
    k.ao_longo("escrivaninha", (porta + 2) % 4) or k.ao_longo("escrivaninha", k.parede_maior(evita=(porta,)))
    for p in sorted(range(4), key=lambda q: q == porta):
        if k.ao_longo("estante", p):
            break


def _jantar(k):
    c = k.c
    mx, my = (c.x0 + c.x1) / 2, (c.y0 + c.y1) / 2
    mesa = k.poe("mesa", mx, my, 0.0 if c.comp(0) >= c.comp(1) else math.pi / 2)
    if mesa:
        cx = mesa["caixa"]
        for (dx, dy, a) in ((0, 1, 0.0), (0, -1, math.pi), (1, 0, -math.pi / 2), (-1, 0, math.pi / 2)):
            k.poe("cadeira", mx + dx * ((cx[2] - cx[0]) / 2 + 0.3), my + dy * ((cx[3] - cx[1]) / 2 + 0.3), a)
    k.ao_longo("aparador", k.parede_maior(evita=(k.parede_da_porta(),)))


REGRAS = {"sala": _sala, "quarto": _quarto, "quarto_crianca": lambda k: _quarto(k, True), "cozinha": _cozinha,
          "banheiro": _banheiro, "lavanderia": _lavanderia, "garagem": _garagem, "escritorio": _escritorio,
          "jantar": _jantar, "corredor": lambda k: None}


def compoe(tipo, comodo, rng):
    """Monta o cômodo. Devolve (itens, problemas). Itens: dicts com tipo, nome, x, y, ang."""
    k = Compositor(comodo, rng)
    REGRAS[tipo](k)
    return k.itens, k.valida()
