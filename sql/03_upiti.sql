-- ============================================================
-- Analitički upiti za bazu Odbojkaška liga (Oracle)
-- Pokreće se nakon 01_ddl.sql i 02_podaci.sql.
-- ============================================================


-- 1) Gledanost klubova: prosjek, minimum i maksimum gledatelja po
--    utakmici (domaće utakmice) u usporedbi s kapacitetom dvorane.
SELECT
    k.ime AS Klub,
    d.Naziv AS Dvorana,
    d.Adresa,
    COUNT(u.ID_UTAKMICA) AS Broj_utakmica,
    SUM(u.broj_gledatelja) AS broj_gledatelja,
    ROUND(AVG(u.broj_gledatelja), 2) AS Prosjek_gledalaca_po_utakmici,
    MAX(u.broj_gledatelja) AS Maksimalno_gledalaca,
    MIN(u.broj_gledatelja) AS Minimalno_gledalaca,
    d.kapacitet AS Kapacitet
FROM
    klubovi k
    JOIN utakmice u ON k.id_klub = u.klubovi_id_klub_domaci  -- domaće utakmice
    JOIN dvorane d ON u.dvorane_id_dvorana = d.id_dvorana
GROUP BY
    k.ime, d.naziv, d.adresa, d.kapacitet
ORDER BY
    broj_gledatelja DESC;


-- 2) Usporedba igrača po pozicijama: broj nastupa i prosječne
--    vrijednosti napada, blokova, servisa i prijema.
SELECT
    i.ime || ' ' || i.prezime AS Igrac,
    ik.pozicija,
    COUNT(DISTINCT i.id_igrac) AS Broj_igraca,
    COUNT(DISTINCT n.utakmice_id_utakmica) AS Ukupno_nastupa,
    ROUND(AVG(n.broj_napada_dobr), 2) AS Prosjek_uspjesnih_napada,
    ROUND(AVG(n.broj_blokova_dobr), 2) AS Prosjek_blokova,
    ROUND(AVG(n.broj_servi_dobr), 2) AS Broj_dobrih_servi,
    ROUND(AVG(n.broj_rc_dobr), 2) AS Prosjek_spasavanja
FROM
    igraci i
    INNER JOIN nastupi n ON i.id_igrac = n.igraci_id_igrac
    INNER JOIN igrac_klub ik ON i.id_igrac = ik.igraci_id_igrac
GROUP BY
    ik.pozicija, i.ime, i.prezime
ORDER BY
    Broj_igraca DESC;


-- 3) Pet igrača s najboljim postotkom uspješnih napada
--    (uzimaju se samo igrači s barem 10 napada).
SELECT * FROM (
    SELECT
        i.Ime || ' ' || i.Prezime AS Igrac,
        SUM(n.broj_napada_dobr) AS Uspjesni,
        SUM(n.broj_napada_tot) AS Ukupno,
        ROUND((SUM(n.broj_napada_dobr) / NULLIF(SUM(n.broj_napada_tot), 0)) * 100, 2) || '%' AS Postotak
    FROM
        igraci i
        JOIN nastupi n ON i.id_igrac = n.igraci_id_igrac
    GROUP BY
        i.ime, i.prezime
    HAVING
        SUM(n.Broj_napada_tot) >= 10  -- minimum 10 napada za statistiku
    ORDER BY
        Postotak DESC
)
WHERE ROWNUM <= 5;


-- 4) Forma klubova u zadnjih 5 utakmica: pobjede, porazi, razlika
--    setova i niz rezultata (P = pobjeda, I = poraz).
--    Koristi CTE, prozorsku funkciju ROW_NUMBER i LISTAGG.
WITH Klubske_utakmice AS (
    SELECT
        k.ID_KLUB,
        k.ime,
        u.ID_UTAKMICA,
        u.Datum_odrzavanja,
        CASE
            WHEN (u.klubovi_id_klub_domaci = k.id_klub AND u.domaci_dobiveni_setovi > u.gosti_dobiveni_setovi) OR
                 (u.klubovi_id_klub_gosti = k.id_klub AND u.gosti_dobiveni_setovi > u.domaci_dobiveni_setovi)
                THEN 'Pobjeda'
            ELSE 'Poraz'
        END AS Rezultat,
        CASE
            WHEN u.klubovi_id_klub_domaci = k.id_klub THEN u.domaci_dobiveni_setovi
            ELSE u.gosti_dobiveni_setovi
        END AS Dobiveni_setovi,
        CASE
            WHEN u.klubovi_id_klub_domaci = k.id_klub THEN u.gosti_dobiveni_setovi
            ELSE u.domaci_dobiveni_setovi
        END AS Izgubljeni_setovi,
        ROW_NUMBER() OVER (PARTITION BY k.id_klub ORDER BY u.datum_odrzavanja DESC) AS Rn
    FROM
        klubovi k
        JOIN utakmice u ON k.id_klub = u.klubovi_id_klub_domaci OR k.id_klub = u.klubovi_id_klub_gosti
)
SELECT
    ime,
    COUNT(*) AS Odigrano_utakmica,
    SUM(CASE WHEN Rezultat = 'Pobjeda' THEN 1 ELSE 0 END) AS Pobjede,
    SUM(CASE WHEN Rezultat = 'Poraz' THEN 1 ELSE 0 END) AS Porazi,
    ROUND((SUM(CASE WHEN Rezultat = 'Pobjeda' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0)) * 100, 2) AS Postotak_pobjeda,
    SUM(Dobiveni_setovi) AS Ukupno_dobivenih_setova,
    SUM(Izgubljeni_setovi) AS Ukupno_izgubljenih_setova,
    SUM(Dobiveni_setovi) - SUM(Izgubljeni_setovi) AS Set_razlika,
    LISTAGG(
        CASE WHEN Rezultat = 'Pobjeda' THEN 'P' ELSE 'I' END,
        '-'
    ) WITHIN GROUP (ORDER BY Datum_odrzavanja DESC) AS Forma_niz
FROM
    Klubske_utakmice
WHERE
    Rn <= 5
GROUP BY
    ID_KLUB, ime
ORDER BY
    Postotak_pobjeda DESC, Set_razlika DESC;
