#!/usr/bin/env python3
"""Generate the README architecture diagram, one SVG per colour scheme.

Two files rather than one self-switching file: GitHub strips <style> blocks
from inline SVG, so a `prefers-color-scheme` media query inside the document is
silently dropped. The README pairs them with <picture>, which GitHub honours.

A README diagram is studied, not narrated, so it is COMPLETE rather than
minimal: the NAT gateway, the secret store, both EFS mounts, the Samba hop to
Windows and the domain membership of both hosts are all on it.

Run:  python3 make_diagram.py
"""

import os

HERE = os.path.dirname(os.path.abspath(__file__))

# ------------------------------------------------------------------------------
# Geometry and style (shared with the other projects' diagrams)
# ------------------------------------------------------------------------------
NW, NH = 420, 110                          # node width, height
GUTTER = 140                               # between columns: room for a label
MARGIN = 40
COL = [MARGIN + i * (NW + GUTTER) for i in range(3)]
ROW = [40, 240, 440]
BOTTOM = 70                                # room for the Windows domain line
W = MARGIN * 2 + NW * 3 + GUTTER * 2
H = ROW[2] + NH + BOTTOM
TITLE_PX, SUB_PX, EDGE_PX = 26, 17, 16

THEMES = {
    "dark": {
        "bg": "#0d1117", "panel": "#161b22", "text": "#e6edf3",
        "muted": "#8b949e", "line": "#58a6ff", "local": "#39c5bb",
        "purple": "#c39be8", "navy": "#c8d6e8", "blue": "#58a6ff",
        "amber": "#f2c163", "store": "#7ee787",
    },
    "light": {
        "bg": "#ffffff", "panel": "#f6f8fa", "text": "#1f2328",
        "muted": "#59636e", "line": "#0969da", "local": "#137e77",
        "purple": "#8250df", "navy": "#475467", "blue": "#0969da",
        "amber": "#9a6700", "store": "#1a7f37",
    },
}

# Lucide icon paths, on a 24-unit grid.
ICONS = {
    "globe": ['<circle cx="12" cy="12" r="10"/>',
              '<path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/>',
              '<path d="M2 12h20"/>'],
    "route": ['<circle cx="6" cy="19" r="3"/>', '<circle cx="18" cy="5" r="3"/>',
              '<path d="M12 19h4.5a3.5 3.5 0 0 0 0-7h-8a3.5 3.5 0 0 1 0-7H12"/>'],
    "network": ['<rect x="16" y="16" width="6" height="6" rx="1"/>',
                '<rect x="2" y="16" width="6" height="6" rx="1"/>',
                '<rect x="9" y="2" width="6" height="6" rx="1"/>',
                '<path d="M5 16v-3a1 1 0 0 1 1-1h12a1 1 0 0 1 1 1v3"/>',
                '<path d="M12 12V8"/>'],
    "layers": ['<path d="m12.83 2.18a2 2 0 0 0-1.66 0L2.6 6.08a1 1 0 0 0 0 1.83'
               'l8.58 3.91a2 2 0 0 0 1.66 0l8.58-3.9a1 1 0 0 0 0-1.83Z"/>',
               '<path d="m22 17.65-9.17 4.16a2 2 0 0 1-1.66 0L2 17.65"/>',
               '<path d="m22 12.65-9.17 4.16a2 2 0 0 1-1.66 0L2 12.65"/>'],
    "database": ['<ellipse cx="12" cy="5" rx="9" ry="3"/>',
                 '<path d="M3 5V19A9 3 0 0 0 21 19V5"/>',
                 '<path d="M3 12A9 3 0 0 0 21 12"/>'],
    "key": ['<path d="M2.586 17.414A2 2 0 0 0 2 18.828V21a1 1 0 0 0 1 1h3a1 1 0 0 0 '
            '1-1v-1a1 1 0 0 1 1-1h1a1 1 0 0 0 1-1v-1a1 1 0 0 1 1-1h.172a2 2 0 0 0 '
            '1.414-.586l.814-.814a6.5 6.5 0 1 0-4-4z"/>',
            '<circle cx="16.5" cy="7.5" r=".5"/>'],
    "monitor": ['<rect width="20" height="14" x="2" y="3" rx="2"/>',
                '<line x1="8" x2="16" y1="21" y2="21"/>',
                '<line x1="12" x2="12" y1="17" y2="21"/>'],
    "terminal": ['<polyline points="4 17 10 11 4 5"/>',
                 '<line x1="12" x2="20" y1="19" y2="19"/>'],
    "users": ['<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/>',
              '<circle cx="9" cy="7" r="4"/>',
              '<path d="M22 21v-2a4 4 0 0 0-3-3.87"/>',
              '<path d="M16 3.13a4 4 0 0 1 0 7.75"/>'],
}

NODES = {}


def _r(nid):
    """Return (left, top, right, bottom, centre-x, centre-y) for a node."""
    x, y = NODES[nid][0], NODES[nid][1]
    return x, y, x + NW, y + NH, x + NW / 2, y + NH / 2


def gutter_x(c):
    """Centre of the gutter to the right of column c."""
    return COL[c] + NW + GUTTER / 2


def gutter_y(r):
    """Centre of the gap below row r."""
    return ROW[r] + NH + (ROW[1] - ROW[0] - NH) / 2


# ------------------------------------------------------------------------------
# Layout
# ------------------------------------------------------------------------------
# The Linux gateway is the hub (amber, the subject of the project): it is the
# only host that mounts EFS, and it re-shares that mount to Windows over SMB.
# EFS sits to its left, Windows to its right, clients come in from above, and
# the domain controller anchors the bottom row with the NAT gateway and the
# secret store either side of it.
#
# id: (x, y, colour key, icon, title, subtitle)
NODES.update({
    "client":   (COL[1], ROW[0], "navy", "globe", "SSH / RDP client",
                 "from the internet, AD credentials"),
    "efs":      (COL[0], ROW[1], "store", "database", "Amazon EFS",
                 "mcloud-efs, encrypted, 2 mount targets"),
    "linux":    (COL[1], ROW[1], "amber", "terminal", "EFS Client Gateway",
                 "Ubuntu 24.04, Samba, public subnet"),
    "windows":  (COL[2], ROW[1], "blue", "monitor", "Windows Server 2022",
                 "windows-ad-admin, RSAT, public subnet"),
    "nat":      (COL[0], ROW[2], "navy", "network", "NAT Gateway",
                 "outbound for the private DC subnet"),
    "dc":       (COL[1], ROW[2], "purple", "users", "mini-AD (Samba DC)",
                 "users, groups, Kerberos, DNS"),
    "secrets":  (COL[2], ROW[2], "store", "key", "Secrets Manager",
                 "AD admin + user passwords"),
})

cli, efs, lx, win = _r("client"), _r("efs"), _r("linux"), _r("windows")
nat, dc, sec = _r("nat"), _r("dc"), _r("secrets")
FAN = 60                      # offset of the secret-store lines from centre
OUT = win[2] + 20             # Windows' domain line runs down the right margin
LOW = H - BOTTOM / 2          # ...and back along the bottom, under the DC row

# id: (path, colour key, label, label_x, label_y, anchor)
EDGES = {
    "e_ssh":    (f"M{cli[4]},{cli[3]} V{lx[1] - 5}", "line",
                 "SSH :22", cli[4] + 14, gutter_y(0) + 6, "start"),
    "e_rdp":    (f"M{cli[2]},{cli[5]} H{win[4]} V{win[1] - 5}", "line",
                 "RDP :3389", gutter_x(1), cli[5] - 12, "middle"),
    "e_nfs":    (f"M{lx[0]},{lx[5]} H{efs[2] + 5}", "store",
                 "NFS :2049 (TLS)", gutter_x(0), lx[5] - 12, "middle"),
    "e_smb":    (f"M{win[0]},{win[5]} H{lx[2] + 5}", "local",
                 "SMB: Z: is /efs", gutter_x(1), win[5] - 12, "middle"),
    "e_sssd":   (f"M{lx[4]},{lx[3]} V{dc[1] - 5}", "purple",
                 "SSSD + winbind", lx[4] - 14, gutter_y(1) + 6, "end"),
    "e_sec":    (f"M{lx[4] + FAN},{lx[3]} V{gutter_y(1) + 18} "
                 f"H{sec[4] - FAN} V{sec[1] - 5}", "store",
                 "join password", gutter_x(1), gutter_y(1) + 8, "middle"),
    "e_winsec": (f"M{win[4] + FAN},{win[3]} V{sec[1] - 5}", "store",
                 "join password", win[4] + FAN + 14, gutter_y(1) + 6, "start"),
    "e_winad":  (f"M{win[2]},{win[5] + 30} H{OUT} V{LOW} H{dc[4]} "
                 f"V{dc[3] + 5}", "purple",
                 "domain member", sec[4], LOW - 10, "middle"),
    "e_nat":    (f"M{dc[0]},{dc[5]} H{nat[2] + 5}", "navy",
                 "outbound", gutter_x(0), dc[5] - 12, "middle"),
}

ALT = ("An SSH client reaches the EFS client gateway, an Ubuntu 24.04 host in "
       "the public subnet, and an RDP client reaches a Windows Server 2022 admin "
       "host beside it. The gateway mounts Amazon EFS over NFS with TLS, for "
       "/home and a shared /efs area, and re-shares /efs over SMB to the Windows "
       "host as drive Z:. Both hosts read the AD join password from Secrets "
       "Manager and join the mini-AD domain controller, which sits in a private "
       "subnet and reaches the internet through a NAT gateway.")

# ------------------------------------------------------------------------------
# Rendering
# ------------------------------------------------------------------------------
FONT = "-apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif"


def node_svg(nid, t):
    """Render one service box: rounded panel, icon, title, subtitle."""
    x, y, key, icon, title, sub = NODES[nid]
    colour = t[key]
    scale = 1.25
    isz = 24 * scale
    ix, iy = x + 20, y + (NH - isz) / 2
    tx = x + 20 + isz + 14
    return "".join([
        f'<rect x="{x}" y="{y}" width="{NW}" height="{NH}" rx="10" ry="10" '
        f'fill="{t["panel"]}" stroke="{colour}" stroke-width="2"/>',
        f'<g transform="translate({ix},{iy}) scale({scale})" fill="none" '
        f'stroke="{colour}" stroke-width="2" stroke-linecap="round" '
        f'stroke-linejoin="round">' + "".join(ICONS[icon]) + "</g>",
        f'<text x="{tx}" y="{y + NH/2 - 4}" font-family="{FONT}" '
        f'font-size="{TITLE_PX}" font-weight="600" fill="{t["text"]}">{title}</text>',
        f'<text x="{tx}" y="{y + NH/2 + 22}" font-family="{FONT}" '
        f'font-size="{SUB_PX}" fill="{t["muted"]}">{sub}</text>',
    ])


def edge_svg(eid, t):
    """Render one arrow plus its label (on a background chip, so lines that
    pass behind a label never cut through its text)."""
    d, key, label, lx, ly, anchor = EDGES[eid]
    colour = t[key]
    out = (f'<path d="{d}" fill="none" stroke="{colour}" stroke-width="2" '
           f'marker-end="url(#a_{eid})"/>')
    if label:
        out += (f'<text x="{lx}" y="{ly}" text-anchor="{anchor}" '
                f'font-family="{FONT}" font-size="{EDGE_PX}" font-weight="600" '
                f'fill="{colour}" stroke="{t["bg"]}" stroke-width="6" '
                f'paint-order="stroke">{label}</text>')
    return out


def build(t):
    """Assemble the diagram for one theme."""
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
           f'viewBox="0 0 {W} {H}" role="img" aria-label="{ALT}">', "<defs>"]
    # One marker per edge: a shared marker cannot carry per-edge colour.
    for eid, spec in EDGES.items():
        out.append(
            f'<marker id="a_{eid}" viewBox="0 0 10 10" refX="9" refY="5" '
            f'markerWidth="5" markerHeight="5" orient="auto-start-reverse">'
            f'<path d="M0,0 L10,5 L0,10 z" fill="{t[spec[1]]}"/></marker>')
    out.append("</defs>")
    out.append(f'<rect width="{W}" height="{H}" fill="{t["bg"]}"/>')
    for eid in EDGES:
        out.append(edge_svg(eid, t))
    for nid in NODES:
        out.append(node_svg(nid, t))
    out.append("</svg>")
    return "".join(out)


def main():
    for name, theme in THEMES.items():
        path = os.path.join(HERE, f"architecture-{name}.svg")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(build(theme))
        print(f"  architecture-{name}.svg")


if __name__ == "__main__":
    main()
