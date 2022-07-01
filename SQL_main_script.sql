--------------------------------------------------------------------------

-- Vorbereitung Datenbank Standard erstellen

use master
go

-- eventuell vorhandene Datenbankspezifische benutzerdefinierte
-- Fehlermeldungen entfernen

if exists(select * from sys.messages where message_id = 50100)
	execute sp_dropmessage '50100', 'all';
go

-- eventuell vorhandene Datenbank "Standard" loeschen


if exists(select * from sys.databases where database_id = db_id('Standard'))
	drop database Standard;
go

-- benutzerdefinierte Fehlermeldung erstellen

sp_addmessage 50100,16,'The delivery of supplier %s of %s, was deleted from the User %s on %s.', 'us_english', 'true';
go
sp_addmessage 50100,16,'Die Lieferung von Lieferant %1! vom %2!, wurde von User %3! am %4! geloescht', 'German', 'true';
go

-- neue Datenbank "Standard" erstellen

create database standard;
/*
on (name = 'Standard',
    filename = 'f:\standard.mdf',
    size = 5MB,
    maxsize = 10MB)
log on (name = 'Standard_Prot',
    filename = 'f:\standard_prot.ldf',
    size = 2MB,
    maxsize = 3MB)
*/
go

use standard;
go


-- Schemas erstellen
 
-- create schema verwaltung authorization dbo;
go
-- create schema einkauf authorization dbo;
go
 


-- Tabellen erstellen

create table dbo.artikel
	(
	anr nchar(3) NOT NULL constraint anr_ps primary key 
	constraint anr_chk check(anr like 'a%' and cast(substring(anr,2,2)as int) between 1 and 99),
	aname nvarchar(50) NOT NULL ,
	farbe nchar (7) NULL constraint farbe_chk check( farbe in ('rot', 'blau', 'gr�n', 'schwarz', 'gelb')),
	gewicht decimal(9,2) NULL ,
	astadt nvarchar(50) NULL ,
	amenge int NULL constraint amenge_chk check( amenge between 0 and 10000));
go


create table dbo.lieferant
	(
	lnr nchar(3) NOT NULL constraint lnr_ps primary key 
	constraint lnr_chk check(lnr like 'l%' and cast(substring(lnr,2,2)as int) between 1 and 99),
	lname nvarchar(50) NOT NULL constraint lname_chk check( lname like '[A-Z]%'),
	status int NULL constraint status_chk check( status between 1 and 99),
	lstadt nvarchar(50) NULL constraint lstadt_chk check( lstadt like '[A-Z]%'));
go


create table dbo.lieferung
	(
	lnr nchar(3) NOT NULL constraint lnr_fs references dbo.lieferant(lnr)
			     on update cascade,
	anr nchar(3) NOT NULL constraint anr_fs references dbo.artikel(anr)
			     on update cascade,
	lmenge int NOT NULL constraint lmenge_chk check( lmenge between 1 and 1000000) ,
	ldatum datetime NOT NULL,
	constraint lief_ps primary key(lnr, anr, ldatum));
go


use standard;
go

-- Tabellen mit Anfangsdaten f�llen
-- Tabelle Lieferant

insert into dbo.lieferant values('L01', 'Schmidt', 20, 'Hamburg');
insert into dbo.lieferant values('L02', 'Jonas', 10, 'Ludwigshafen');
insert into dbo.lieferant values('L03', 'Blank', 30, 'Ludwigshafen');
insert into dbo.lieferant values('L04', 'Clark', 20, 'Hamburg');
insert into dbo.lieferant values('L05', 'Adam', 30, 'Aachen');


-- Tabelle Artikel

insert into dbo.artikel values('A01', 'Mutter', 'rot', 12, 'Hamburg', 800);
insert into dbo.artikel values('A02', 'Bolzen', 'gr�n', 17, 'Ludwigshafen', 1200);
insert into dbo.artikel values('A03', 'Schraube', 'blau', 17, 'Mannheim', 400);
insert into dbo.artikel values('A04', 'Schraube', 'rot', 14, 'Hamburg', 900);
insert into dbo.artikel values('A05', 'Nockenwelle', 'blau', 12, 'Ludwigshafen', 1300);
insert into dbo.artikel values('A06', 'Zahnrad', 'rot', 19, 'Hamburg', 500);


-- Tabelle Lieferung

insert into dbo.lieferung values('L01', 'A01', 300, '18.05.90');
insert into dbo.lieferung values('L01', 'A02', 200, '13.07.90');
insert into dbo.lieferung values('L01', 'A03', 400, '01.01.90');
insert into dbo.lieferung values('L01', 'A04', 200, '25.07.90');
insert into dbo.lieferung values('L01', 'A05', 100, '01.08.90');
insert into dbo.lieferung values('L01', 'A06', 100, '23.07.90');
insert into dbo.lieferung values('L02', 'A01', 300, '02.08.90');
insert into dbo.lieferung values('L02', 'A02', 400, '05.08.90');
insert into dbo.lieferung values('L03', 'A02', 200, '06.08.90');
insert into dbo.lieferung values('L04', 'A02', 200, '09.08.90');
insert into dbo.lieferung values('L04', 'A04', 300, '20.08.90');
insert into dbo.lieferung values('L04', 'A05', 400, '21.08.90');
go


-- Sicherstellen von Geschaeftsregeln
-- Addieren der Liefermenge zur entsprechenden Lagermenge bei neuer Lieferung

-- create trigger menge_lief_neu
-- on einkauf.lieferung
-- for insert
-- as
-- if (select inserted.lmenge from inserted ) > 0
--	begin
--	 update verwaltung.artikel
--	 set amenge = amenge + inserted.lmenge
--	 from verwaltung.artikel join inserted on artikel.anr = inserted.anr;
--	end;
go

-- Subtrahieren der Liefermenge vom der entsprechenden Lagermenge
-- beim Loeschen einer oder mehrerer Lieferungen

-- create trigger lief_l�sch
-- on einkauf.lieferung
-- for delete
-- as
-- update verwaltung.artikel
-- set amenge = amenge - deleted.lmenge
-- from verwaltung.artikel join deleted on artikel.anr = deleted.anr;
go


-- aendern der Lagermenge des entsprechenden Artikels bei aenderung
-- der Liefermenge einer vorhandenen Lieferung

-- create trigger menge_lief_aendern
-- on einkauf.lieferung
-- for update
-- as
-- if update(lmenge)
--   begin
--	update verwaltung.artikel
--	set amenge = amenge + inserted.lmenge - deleted.lmenge
--	from verwaltung.artikel join inserted on artikel.anr = inserted.anr
--	join deleted on artikel.anr = deleted.anr;
--    end;
go


-- aendern der Lagermenge wenn die Artikelnummer einer
-- Lieferung geaendert wird

-- create trigger anummer_lief_aendern
-- on einkauf.lieferung
-- for update
-- as
-- if update(anr)
--   begin
--	update verwaltung.artikel
--	set amenge = amenge - deleted.lmenge
--	from verwaltung.artikel join deleted on artikel.anr = deleted.anr

--	update verwaltung.artikel
--	set amenge = amenge + inserted.lmenge
--	from verwaltung.artikel join inserted on artikel.anr = inserted.anr;
--    end;
go


---------------------------------------------------------------------
TAG 1:

use standard;
go

-- Select ohne Datenquellen

select getdate()                            -- aktuelles Datum

select 5 * 20;

-- Select mit Datenquellen

-- alle Angaben zu allen Lieferanten

select *from lieferant;

-- Der Stern sollte nur fuer Testabfragen verwendet werden
-- Programmierer verwenden die Spaltennamen.

select lnr, lname, status, lstadt
from lieferant;

-- vollqualifierter Name

select lnr, lname, status, lstadt
from sql16serv1.standard.dbo.lieferant;

-- Aus der DB Standard heraus soll die Tabelle Person in Person der DB
-- AdventureWorks2012 abgefragt werden. Dabei soll Datenbankkontex des
-- aufrufenden Stapels nicht geaendert (use...) werden.

select *
from AdventureWorks2012.person.person;


-- ausgewaehlte Spaltenwerte
-- Wohnorte und Namen aller Lieferanten

select lstadt, lname
from lieferant

-- ausgewaehlte Datensaetze
-- dafuer wird die Where - Klausel benoetigt

-- Vergleichsoperatoren

-- Nummern, Namen und Farbe der Artikel die in Hamburg lagern

select anr, aname, farbe from artikel
where astadt = 'Hamburg';

-- Alle Lieferungen nach dem 01.08.90

select * from lieferung
where ldatum > '01.08.1990';

select * from lieferung
where ldatum > '1990-08-01';

-- Alle Lieferungen mit einer Liefermenge von 200 Stueck

select * from lieferung
where lmenge = 200;

-- Bereiche angeben

-- mit between koennen Bereiche definiert werden, Die angegebene Grenzen
-- (von-bis) sind einschliesslich

-- Alle Lieferungen zwischen dem 20.07.90 und dem 18.08.90

select *
from lieferung
where ldatum between '20.07.90' and '18.08.90';

select * from lieferung
where ldatum >= '20.07.90' and ldatum <= '18.08.90';

-- Alle Liefrungen die nicht zwischen dem 20.07.90 und dem 18.08.90
-- geliefert wurden

select *
from lieferung
where ldatum not between '20.07.90' and '18.08.90';

-- between wird hauptsaechlich auf numerische- und Datumsdatentypen
-- angewendet.

-- Alle Lieferanten deren Namen mit dem Buchstaben B bis J beginnen

select * from lieferant
where lname between 'B' and 'J';

-- Jonas wird nicht angezeigt. Warum?

select * from lieferant
where lname between 'B' and 'Jz';

-- Dafuer verwendet man like

------
-- Listen

-- Alle Lieferanten die in Hamburg oder in Aachen wohnen

select * from lieferant
where lstadt = 'Hamburg', 'Aachen'              -- geht nicht

select * from lieferant
where lstadt in('Hamburg', 'Aachen');

select * from lieferant
where lstadt = 'Hamburg' or lstadt = 'Aachen';

-- Alle Lieferanten die nicht in Hamburg oder in Aachen wohnen

select * from lieferant
where lstadt not in('Hamburg', 'Aachen');

------

-- neuen Lieferanten aufnehmen.

insert into lieferant values('L10','Schul%ze',null, null);

select * from lieferant;

-- LIKE Operator

-- kann nur auf alfanummerische Zeichen angewendet werden.
-- verwendet PLatzhalter (Jokerzeichen)

-- Alle Lieferanten die an einem Ort wohnen der mit dem Buchstaben L beginnt.

select * from lieferant
where lstadt like 'L%';

-- Alle Lieferanten deren Namen an zweiter Stelle den Buchstaben L haben.

select * from lieferant
where lname like '_L%';

-- Alle Lieferanten deren Namen an zweiter Stelle den Buchstaben L haben und
-- an vorletzter Stelle den Buchstaben R.

select * from lieferant
where lname like '_L%R_';

insert into lieferant values('L11','Jach',null, null);

insert into lieferant values('L12','Kulesch',null, null);

-- Lieferanten deren Namen mit dem Buchstaben B bis J beginnen

select * from lieferant
where lname like '[B-J]%';

select * from lieferant
where lname like '[BJ]%';

--Alle Lieferanten in deren Namen an keiner Stelle ein A steht

select * from lieferant
where lname like '%[^a]%';                --GGA ---> Katzenklo    

-- besser

select * from lieferant
where lname not like '%a%';

-- Gesucht sind die Lieferanten in deren Namen ein % - Zeichen steht

select * from lieferant
where lname like '%%%';                 --- ???????????

-- Da % ein Platzhalter ist, muss man mit einer Maske arbeiten.

select * from lieferant
where lname like '%y%%' escape 'y';

------

-- Alle Lieferanten deren Wohnort nicht bekannt ist

select * from lieferant
where lstadt = null;                    -- kein Fehler, sondern eine leere Menge
                                        -- jeder Vergleich mit Unbekannt ergibt
                                        -- Unbekannt

insert into lieferant values('L13','Schoeppach','99','Erfurt');

select * from lieferant;

-- Alle Lieferanten ohne Statuswert sollen mit einem Angenommenen Status von 50 
-- angezeigt werden

select lnr, lname, isnull(status,50) as [status], lstadt
from lieferant;

------

-- Arbeit mit mehreren Bedingungen in der WHERE - Klausel

select * from artikel
where gewicht > 15 and astadt like '[E-L]%'or amenge > 700;

select * from artikel
where gewicht > 15 and(astadt like '[E-L]%'or amenge > 700);

Uebung 1:

1.

-- schreiben die 3 Abfragen 
-- (Vergleichsoperatoren und Schluesselwoerter "between" und "in")
-- die alle Lieferungen vom 5. bzw 6. August 1990 ausgeben

select *
from lieferung
where ldatum between '05.08.1990' and '06.08.1990'

select * 
from lieferung
where ldatum in ('05.08.1990', '06.08.1990')

select * 
from lieferung
where ldatum >= '05.08.1990' and ldatum <= '06.08.1990';

2.

-- schreiben sie eine Abfrage, die die Nummern und Namen aller roten
-- oder blauen Artikel aus Hamburg ausgibt sowie die Artikel die eine 
-- Lagermenge zwischen 900 und 1500 Stueck haben und in deren 
-- Name ein "a" vorkommt

select  anr, aname from artikel
where Farbe in('rot','blau') and astadt ='Hamburg' or 
amenge between 900 and 1500 and aname like '%a%';

3.

-- schreiben sie eine Abfrage, die alle Lieferanten ausgibt, deren 
-- Namen mit einem Buchstaben zwischen A und G beginnt

select * from lieferant
where lname between 'A' and 'G';

select * from lieferant
where lname like '[a-g]%';

4.

-- schreiben sie eine Abfrage, die alle Lieferanten ausgibt, deren Namen
-- mit "S", "C" oder "B" beginnen und wo der dritte Buchstabe im Namen
-- ein "a" ist, die aber in einem Ort wohnen in dessen
-- Namen die Zeichenfolge "ried" nicht vorkommt

select * from lieferant
where lname like '[BCS]_a%_' and lstadt not like 'ried%';

-	Ueberpruefen mit

insert into lieferant values('L20', 'Braun', 5, 'Riednordhausen');
go

5.

-- schreiben sie eine Abfrage zur Ausgabe aller Artikel
-- es sollen jedoch nur die Artikel ausgegeben werden, deren Gewicht 
-- null Gramm betraegt oder unbekannt ist

select * from artikel
where gewicht = 0 or gewicht is null;

select * from artikel

insert into artikel values('A11', 'Kurwa', 'rot', null, 'Riednordhausen', 100)

insert into artikel values('A12', 'Lauch', 'blau', 0, 'Mittelried', 1200)

--------------------------------------------------------------------------------

TAG 2:

use standard
go

select anr, aname, gewicht, astadt, amenge
from artikel
where anr in('A01','A02','A03')

-- Ergebnisse formatieren

-- 1. Literale (erlaeuternder Text)

-- beschreibt den Inhalt einer Spalte

select anr, aname, gewicht 'Gramm', astadt, amenge 'Stueck'
from artikel
where anr in('A01','A02','A03')

-	aendern der Spaltennamen

select anr as [Artikelnummer], aname as [Artikelname], 
gewicht as [Gewicht], 'Gramm' as [Gewichtseinheit], 
astadt as [Lagerort], amenge as [Lagermenge], 'Stueck' as [Lagereinheit]
from artikel
where anr in('A01','A02','A03')

--oder

select anr  [Artikelnummer], aname [Artikelname], 
gewicht [Gewicht], 'Gramm' [Gewichtseinheit], 
astadt [Lagerort], amenge [Lagermenge], 'Stueck' [Lagereinheit]
from artikel
where anr in('A01','A02','A03')

--oder

select   [Artikelnummer] = anr, [Artikelname] = aname,  
  [Gewicht] = gewicht,  [Gewichtseinheit] = 'Gramm', 
  [Lagerort] = astadt, [Lagermenge] = amenge, [Lagereinheit] = 'Stueck'
from artikel
where anr in('A01','A02','A03')

-- Sortieren der Ergebnismenge
-- das Ergebnis soll nach dem Artikelnamen aufsteigend sortiert werden
-- und bei gleichen Artikelnamen nach dem Lagerort absteigend sortiert werden

select anr as [Artikelnummer], aname as [Artikelname], 
gewicht as [Gewicht], 'Gramm' as [Gewichtseinheit], 
astadt as [Lagerort], amenge as [Lagermenge], 'Stueck' as [Lagereinheit]
from artikel
order by aname asc, astadt desc;

-- oder

select anr as [Artikelnummer], aname as [Artikelname], 
gewicht as [Gewicht], 'Gramm' as [Gewichtseinheit], 
astadt as [Lagerort], amenge as [Lagermenge], 'Stueck' as [Lagereinheit]
from artikel
order by [Artikelnummer] asc, [Lagerort] desc;

-- oder

select anr as [Artikelnummer], aname as [Artikelname], 
gewicht as [Gewicht], 'Gramm' as [Gewichtseinheit], 
astadt as [Lagerort], amenge as [Lagermenge], 'Stueck' as [Lagereinheit]
from artikel
order by 2 asc, 5 desc;

-- Entfernen doppelter Datensaetze aus dem Ergebnis

-- Schluesselwort DISTINCT entfernt doppelte DS aus dem Ergebnis
-- Distinct wird eingesetzt
--                  1. in der Select Liste
--                  2. in Argument einer Aggregatfunktion

-- Welche Lieferungen (lnr) haben geliefert?

select lnr from lieferung       -- 12 DS mit redundanten Informationen

select distinct lnr from lieferung;     --4DS

select distinct lnr from lieferant;     -- Sinnlos, unverschaemt blamabel

-- CASE Ausdruecke

-- Einfaches CASE
-- es wird ein Ausdruck mit mehreren anderen Ausdruecken verglichen um das
-- Resultset zu finden

select lnr, lname, lstadt, case lstadt
                           when 'Hamburg' then 'wohnt im Norden'
                           when 'Ludwigshafen' then 'wohnt im Westen'
                           else 'wohnt auch'
                           end as [Bewertung]

from lieferant;

delete lieferant where lnr > 'L05';

-- komplexes CASE
-- hierbei werden wie bei einer WHERE - Klausel Bollsche Ausdruecke 
-- Ueberprueft und bei Uebereinstimmungen ein Resultset zurueckgegeben

select anr, aname, amenge, farbe, 
       case
       when amenge = 1200 and farbe = 'gruen' then 'toller Artikel'
       when amenge = 1300 and farbe = 'blau' then 'noch toller'
       else 'auch toll'
       end as [Bewertung]
from artikel;

-- Berechnen von Ergebnismengen und arbeiten mit Funktionen

-- Arithmetische Operatoren

select 2 + 6;
select 3 - 9;
select 2 * 3;
select 2 * 3.3;
select 5 / 2;       -- Ganzzahl der Division
select 5 / 2.0;     -- korrektes Ergebnis
select 5 % 2;       -- ganzzahliger Divisionsrest

select anr, aname, gewicht * 0.001 as [GEwicht in Kilo],
       amenge * gewicht * 0.001 as [Gesamtlagergewicht]
from artikel;

-- Operator + fuer die Verkettung von Zeichenfolgen

select 'Der Lieferant' + lname + ' (' + lnr + '), wonht in ' +
        lstadt + ' und hat einen Status von ' + cast(status as varchar(10))
from lieferant;

-- Skalare Funktionen

select lname, DATALENGTH(lname) as [Anzahl Byte] len(lname) as[Anzahl Zeichen]
from lieferant;

select host_name();             -- Name des Servers auf dem SQL Server laeuft
select host_id();               -- ID der aktuellen Arbeitsstation

select user_name();             -- Datenbankbenutzername
select user_id();
select suser_name()             -- Login
select suser_id();

select newid();

-- mathematische Funktionen

select round(233.871, 2);       -- auf/abrunden
select round(233.871, -2);

select rand();                  -- eine zufuellige Zahl zwischen 0 und 1
select round(rand() * 100,0)

-- Zeichenfolge Funktionen

select char(39);                -- ASCI Zeichen Hochkomma

select replace('Hustensaftschmuggler', 'saft', 'bier');

select replicate('Bier' , 10); 

-- Namen und Wohnort der Lieferanten in einer Spalte mit einem Abstand von 20 
-- Leerzeichen

select lname + space(20) + lstadt
from lieferant;

--Gesucht ist der zweite Buchstabe jedes Lieferantennamen

select lname, substring(lname,2,1) [zweiter Buchstabe]
from lieferant

-- der Chef moechte die Lieferantennummern statt mit einem L mit einem K
-- beginnen lassen und der numerische Teil soll dreistellig sein und bei
-- 101 beginnen

select lnr
from lieferant;

--numerischen Teil und alfanumerischen Teil trennen

select substring(lnr,2,2)
from lieferant

-- Ziffern in Zahlen umwandeln

select cast(substring(lnr,2,2) as int)
from lieferant

-- um 100 erhoehen

select cast(substring(lnr,2,2) as int) +100
from lieferant

-- vor die Zahl das K setzten, dazu muss die Zahl vorher String werden

select 'K' + cast(cast(substring(lnr,2,2) as int) +100 as varchar(4))
from lieferant;

-- Datums- und Zeitfunktion

select getdate();
select year(getdate());             -- Ergebnis numersich
select month(getdate());            -- Ergebnis numersich
select day(getdate());              -- Ergebnis numersich

select lnr, ldatum, day(ldatum), month(ldatum), year(ldatum)
from lieferung;

select date();

-- bestimmen welcher Wochentag der Wochenbeginn ist

-- fuer Deutschland

select @@datefirst;                 -- 1 --> Montag

-- fuer USA

set language us_englisch;
select @@datefirst;                 -- 7 --> Sonntag

-- Russia
set language russian;
select @@datefirst;                 -- 1 --> Montag

-- Datumsfuntionen zum Berechnen von Datumswerten

select datename(dw,getdate());      -- Mittwoch --> alfanumerisch
select datename(mm,getdate());      -- Juni     --> alfanumerisch
select datename(yyyy,getdate());    -- 2022     --> alfanumerisch

select datepart(dd,getdate());      -- 1        --> numerisch
select datepart(mm,getdate());      -- 6        --> numerisch
select datepart(yyyy,getdate());    -- 2022     --> numerisch

-- Alle im August 1990 durchgefuehrten Lieferungen

select * from lieferung
where datepart(mm,ldatum) = 8
and datepart (yyyy,ldatum) = 1990;

-- Zahlungstermin 37 Tage nach  Lieferdatum

select lnr, anr, ldatum, dateadd(dd, 37, ldatum) as [Zahlung]
from lieferung;

-- Anzahl der Monate seit Lieferung bis Heute

select lnr, anr, ldatum, datediff(mm,ldatum,getdate()) as [Anzahl Monate]
from lieferung;

-- Datum Konvertieren

-- nicht mit cast() konvertieren, da sonst unerwartete Ergebnisse
-- auftreten

-- Lieferungen in einem deutschen Format (dd.mm.yyyy) darstellen.

select lnr, anr, cast(ldatum as char(10)) from Lieferung

-- besser ist die Funktion convert

select lnr, anr, convert(char(10),ldatum,104) from Lieferung;

Uebung 2:

1.

-- Schreiben sie eine Abfrage auf Tabelle Lieferung 
-- in der Datenbank Standard, welche ihnen nachstehendes 
-- Ergebnis liefert

select anr as [Artikelnummer], lmenge as [Liefermenge], 
datename(dw,ldatum)+' der '+
datename(dd,ldatum)+'. '+
datename(mm,ldatum)+' '+
datename(yyyy,ldatum) as [Lieferdatum]
from lieferung;

2.

-- Schreiben sie eine Abfrage auf Tabelle Lieferung 
-- in der Datenbank Standard, welche ihnen nachstehendes  
-- Ergebnis liefert

select anr as 'Artikelnummer', convert(char(10),ldatum,104) as 'Lieferdatum',
'vor ' + cast(datediff(dd, convert(datetime,ldatum,104), getdate())/365 as varchar(10)) +
' Jahren und ' +
cast(cast(datediff(dd, ldatum, getdate()) % 365.25/30.4375 as int) as varchar(2))
+ ' Monaten.' as 'Die Lieferung ...'
from lieferung;

-----------------------------------------------------------------------------

TAG 3:

use standard
go 

-- Gruppieren und Zusammenfassen von Dateien

-- Aggregatfunktionen

-- sie beziehen sich auf die Daten einer Spalte der Tabelle (ausser count)
-- und geben einen Zusammenfassungswert zurueck

-- das Ergebnis ist genau ein Wert

-- alle Aggregatfunktionen ignorieren NULL-Marken

-- die fuenf am haufigsten gebrauchten Aggregatfunktionen sind

--      avg     (average) Durchschnitt der nummerischen Spaltenwerte
--      max     der groesste Spaltenwert
--      min     der kleinste Spaltenwert
--      sum     die Summe der nummerischen Spaltenwerte 
--      count   die Anzahl der Spaltenwerte

select  sum(lmenge) as [Liefermenge gesamt],
        max(lmenge) as [groesste Liefermenge],
        min(lmenge) as [kleinste Liefermenge],
        avg(lmenge) as [durchschnittliche Liefermenge],
        count(lnr) as [Anzahl der Lieferungen]
from lieferung;

-- Die groesste Liefermenge

select max(lmenge) from lieferung;

-- Neugierig: ich will wissen wer das ist!

select max(lmenge),lnr from lieferung;   -- Fehler

-- Alle Spalten in der Select-Liste die kein Argument einer Aggregatfunktion
-- sind muessen in einer group by Klausel stehen

select max(lmenge),lnr from lieferung
group by lnr;

-- das veraendert die Fragestellung
-- die groesste Lieferung eines jeden Lieferanten

-- Agregatfunktion COUNT

insert into Lieferant values('L10','Meier',null,'Erfurt')

-- Anzahl der Lieferanten

select count(lnr) from lieferant;       -- immer richtig, weil die Primaer-Spalte 
                                        -- als Argument verwendet wird

select count(*) from lieferant;         -- immer richtig, weil es in einer Tabelle
                                        -- keine leeren Datensaetze gibt
                                        -- count(*) zaehlt die DS (Datensaetze) der
                                        -- angebenen Tabelle

select count(status) from lieferant;    -- nicht immer richtig,weil die Spalte 
                                        -- Unbekannte WErte enthalten kann.

-- alle Aggregatfunktionen ignorieren NULL-Marken

select count(lnr) from lieferant;       -- 6 DS
select count(status) from lieferant;    -- 5 DS

-------
select *
from lieferant

-- Das groesste Gesamtlagergewicht aller Artikel in Kilo

select gewicht * 0.001 * amenge as [Gesamtlagergewicht]
from artikel;

select max(gewicht * 0.001 * amenge)
from artikel;

-- die letzte Lieferung von 'A02'

select max(ldatum) from lieferung where anr = 'A02'

-- Anzahl der Lieferanten die geliefert haben

select count(lnr) from lieferung;          -- FALSCH -- liefert die Anzahl 
                                                     -- der Lieferungen

select count(distinct lnr) from lieferung; -- RICHTIG

-- Gesucht ist die groesste Status der Lieferanten am jeweiligen
-- Wohnort ...

select lstadt, max(status)
from lieferant
group by lstadt;

-- ... wenn der duschschnittliche Statuswert am jeweiligen Wohnort nicht kleiner
-- als 15 ist

select lstadt, max(status)
from lieferant
where avg(status) > 15
group by lstadt;                -- FALSCH

-- in einer Where-KLausel darf niemals eine Aggregatfunktion stehen.
-- Die Bedingung ist eine Bedingung fuer die Gruppe!

select lstadt, max(status)
from lieferant
group by lstadt
having avg(status) > 15;

-- ohne die Aachner Lieferanten

select lstadt, max(status)
from lieferant
group by lstadt
having avg(status) > 15 and lstadt <> 'Aachen';     -- Unanstaendig

select lstadt, max(status)
from lieferant
where lstadt <> 'Aachen'
group by lstadt
having avg(status) > 15;                            -- RICHTIG


Uebung 3:

1.

-- schreiben sie eine Abfrage, die alle im August durchgefuehrten 
-- Lieferungen zaehlt

select count(lnr) as [Anzahl der Lieferungen]
from lieferung
where datepart(mm,ldatum) = 8

-- pruefen mit
select *
from lieferung

2.

-- schreiben sie eine Abfrage, welche die Anzahl aller Nicht-Nullwerte 
-- des Feldes "lstadt" in der Lieferantentabelle ermittelt

select count(lstadt) from lieferant;

3.

-- schreiben sie eine Abfrage, die die jeweils kleinste Lieferung eines
-- jeden Lieferanten anzeigt

select lnr, min(lmenge) 
as [kleinste Liefermenge] 
from lieferung
group by lnr                    

4.

-- schreiben sie eine Abfrage, die den ersten Lieferanten ermittelt, dessen
-- Name mit "S" beginnt (in alphabetischer Reihenfolge)

select * from lieferant
where lname like '[s]%'
order by lname asc

-- oder

select min(lname)
from lieferant
where lname like 's%';

5.

-- schreiben sie eine Abfrage, mit der sie den hoechsten Lagerbestand von
-- Artikeln am jeweiligen Lagerort ermitteln koennen

select astadt, max(amenge)
from artikel
group by astadt;

-- pruefen mit
select * from artikel

6.

-- wie viele unterschiedliche Artikel wurden von jedem Lieferanten geliefert

select lnr, 
count (distinct anr)
from Lieferung
group by lnr;

7.

-- gesucht sind die Artikelnummern die weniger als dreimal geliefert wurden

select anr
from lieferung
group by anr
having count (anr) < 3

8.

-- gesucht sind die Lieferantennummern und die Gesamtliefermenge der Lieferanten
-- die seit dem 13.07.1990 eine Gesamtliefermenge von mehr als 600 Stueck hatten

select lnr, sum (lmenge)
from lieferung
where ldatum >= '13.07.1990'
group by lnr
having sum (lmenge) > 600

9.

-- gesucht ist der in den jeweiligen Wohnorten der Lieferanten kleinste und groesste
-- Statuswert, fuer alle die Lieferanten mit einer Lieferantennummer zwischen
-- "L01" und "L99" wenn der kleinste Statuswert der jeweiligen Stadt 10 uebersteigt
-- und der groesste Statuswert der jeweiligen Stadt 50 nicht uebersteigt

select min(status), max(status), lstadt
from lieferant
where lnr between 'L01' and 'L99'
group by lstadt
having min(status) > 10 and max(status) <= 50;

---------------------------------------------------------------------

TAG 4

insert into lieferung values('L04', 'A03', 500, '10.06.2021');
insert into lieferung values('L04', 'A02', 500, '20.06.2021');
insert into lieferung values('L04', 'A01', 500, '01.06.2022');
insert into lieferung values('L04', 'A03', 500, CONVERT(char(10),GETDATE(),104));

select *
from lieferung

-- CUBE und ROLLUP
-- ermoeglichen zusammen mit Aggregatfunktionen erweiterte Zusammenfassungswerte
-- die Funktionen werden in der group by-Klausel verwendet

-- die Lieferantennummer, der Monat der Lieferung , das Jahr der Lieferung und
-- die Gesamtliefermenge aller Lieferanten mit einer Liefermenge
-- von mind. 100 Stueck

select lnr, datename(mm,ldatum) as [Monat], datepart(yyyy,ldatum) as [Jahr],
sum(lmenge) as [Gesamtliefermenge]
from lieferung
where lmenge >= 100
group by lnr, datename(mm,ldatum), datepart(yyyy,ldatum);

-- Da wir ein sehr grosses Gruppenbildungsmerkmal verwenden muessen
-- Ergebniss wenig aussagekraeftig
--          eine Gesamtliefermenge ueber alle Lieferungen
--          eine Gesamtliefermenge fuer jeden Lieferanten
--          eine Gesamtliefermenge fuer jeden Lieferanten im jeweiligen Monat
--          eine Gesamtliefermenge fuer jeden Lieferanten im jeweiligen Monat und Jahr

select lnr, datename(mm,ldatum) as [Monat], datepart(yyyy,ldatum) as [Jahr],
sum(lmenge) as [Gesamtliefermenge]
from lieferung
where lmenge >= 100
group by rollup (lnr, datename(mm,ldatum), datepart(yyyy,ldatum))
order by 1,2,3;

-	uebertreiben -- weiter Zwischenaggragate

select lnr, datename(mm,ldatum) as [Monat], datepart(yyyy,ldatum) as [Jahr],
sum(lmenge) as [Gesamtliefermenge]
from lieferung
where lmenge >= 100
group by cube (lnr, datename(mm,ldatum), datepart(yyyy,ldatum))
order by 1,2,3;

-- loeschen

delete lieferung where lmenge = 500

-- pruefen

select * from lieferung

-- Rangfolgefuntionen
--      RANK    
--      DENSE-RANK
--      ROW_NUMBER

-- RANK 

-- Rangfolge der Lieferanten anhand ihrer Gesamtlieferungen

select lnr, rank() over(order by sum(lmenge) desc) as [Rang], sum(lmenge)
        as [Gesamtliefermenge]
from lieferung
group by lnr;

insert into lieferung values('L02','A04',200,'03.06.2022');

-- bei gleicher Rangfolge ensteht in der Spalte Rang eine Luecke.

-- DENSE_RANK

select lnr, dense_rank() over(order by sum(lmenge) desc) as [Rang], sum(lmenge)
        as [Gesamtliefermenge]
from lieferung
group by lnr;

-- Zeilennummern mit ROW_NUMBER

-- Alle Angaben zu den Lieferanten zuzueglich einer laufenden Nummer

select row_number() over(order by lnr asc) as [laufende Nummer],
        lnr, lname, lstadt
from lieferant;

-- das Ergebnis einer Abfage in eine Datenbanktabelle speichern
-- er kann gespeichert werden in eine neue permanenten Tabelle
-- oder in temporaeren Tabellen
-- temporaere Tabellen koennen lokal oder gobal sein
-- temporaere Tabellen koennen von jedem Datenbanbenutzer erstellt werden
-- sie existieren solange wie die Sitzung die sie erstellt hat existiert

-- permanente Tabellen koennen nur von Benutzern mit der Berechtigung
-- create table.. und der alter schema.. Berechtigung fuer das Schema
-- wo die Tabelle erstellt wird, erstellt werden.

-- 1. permanente Tabelle

select row_number() over(order by lnr asc) as [laufende Nummer],
        lnr, lname, lstadt
into lief_m_nr
from lieferant;

-- pruefen

select * from lief_m_nr;

-- 2. lokal temp. Tabelle

select row_number() over(order by lnr asc) as [laufende Nummer],
        lnr, lname, lstadt
into #lief_m_nr
from lieferant;

-- pruefen

select * from #lief_m_nr;

-- 3. globale temp. Tabelle

select row_number() over(order by lnr asc) as [laufende Nummer],
        lnr, lname, lstadt
into ##lief_m_nr
from lieferant;

select * from ##lief_m_nr;

-- am temporaersten sind Tabellenvariable

-- diese existieren fuer die Zeitdauer eines Stapels

declare @tab table([Laufende Nummer] int,
                  Lieferantennummer char(3),
                  Namen varchar(100),
                  Ort varchar(100));

insert into @tab select row_number() over(order by lnr asc) as [laufende Nummer],
        lnr, lname, lstadt
        from lieferant;

select * from @tab;
go

-------

use standard;
go

-- Mengenoperatoren aus der Mengenmathematik

-- Adition
-- Subtraktion
-- Schnittmenge

-- Union M1 + M2 = M2/M2

--Alle Orte die Wohnorte und Lagerorte sind

select lstadt from lieferant
union
select astadt from artikel;

-- beide Abfragen links und rechts vom Operator muessen die gleiche Anzahl
-- von Spalten haben und  die Spalten muessen zueinander kompatibel sein.
-- das nennt man Union-Kompatibilitaet

-- das formatieren des Ergbnis

select lstadt as [Wohn-und Lagerorte] from lieferant
union
select astadt from artikel
order by lstadt desc;

-- Union eleminiert doppelte Datensaetze im Ergebnis (wie distinct)
-- das kann ich ausschalten

select lstadt as [Wohn-und Lagerorte] from lieferant
union all
select astadt from artikel
order by lstadt desc;

-- EXCEPT
-- entspricht einer Subtraktion -- gibt saemtliche Datensaetze der
-- Abfrage links vom Operator zurueck, die nicht in der Abfrage rechts
-- vom Operator vorkommen

-- Wohnort von Lieferanten wo keine Artikel gelagert sind

select lstadt as [Wohn-und Lagerorte] from lieferant
except
select astadt from artikel;

-- INTERSEC
-- gibt saemtliche Datensaetze zurueck die sowohl in der Abfrage rechts vom Operator
-- als auch in der Abfrage links vom Operator vorkommen

-- Ortsnamen wo Lieferanten wohnen und auch Artikel gelagert werden

select lstadt as [Orte] from lieferant
intersect
select astadt from artikel;

-- Gesucht sind Nummer, Namen und Wohnorte der Lieferanten
-- die dort wohnen wo Artikel A04 lagert.

select lnr, lname, lstadt
from lieferant
where lstadt = (select astadt from artikel where anr = 'A04');

-- Gesucht sind die Nummmern und Namen der Artikel die bereits geliefert wurden.

select anr from lieferung

select anr, aname
from artikel
where anr in(select anr from lieferung);

/*
Welche Hamburger Lieferanten haben nach dem 01.08.90 rote und blaue
Artikel geliefert?
*/

select farbe from artikel

select lname from lieferant

select ldatum from lieferung

select anr from artikel where farbe in('rot','blau')

select *
from lieferant
where lstadt = 'Hamburg'
and lnr in (select lnr
        from lieferung
        where ldatum > '01.08.90'
        and anr in(select anr from artikel where farbe in('rot','blau')))

-----------------------------------------------------------------------

TAG 5:

Uebung 4:

/*
Alle Angaben zu den Lieferanten deren Statuswert ueber dem durchschnittlichen
Statuswert der Lieferanten liegt, die in der gleichen Stadt wohnen
wie Lieferant L02.
*/

select lstadt
from lieferant
where lnr = 'L02'

select avg(status) 
from lieferant

select * from lieferant
where status > (select avg(status) from lieferant
            where lstadt = (select lstadt from lieferant where lnr = 'L02'))

/*
Nummern und Namen der Artikel die im August 1990 von Lieferanten geliefert wurden 
die mindestens 3x geliefert werden.
*/

-- 1. Frage: welche Lieferanten haben mind. 3 x geliefert?

select lnr from lieferung group by lnr having count(lnr) >= 3

-- 2. Frage: haben diese Lieferanten im August 1990 geliefert

select anr 
from lieferung
        where datepart (mm,ldatum) = 8
        and datepart (yyyy,ldatum) = 1990
        and lnr in (select lnr from lieferung group by lnr having count(lnr) >= 3)

-- 3. Wenn ja was?

(select anr 
        from lieferung
        where datepart (mm,ldatum) = 8
        and datepart (yyyy,ldatum) = 1990
        and lnr in (select lnr from lieferung group by lnr having count(lnr) >= 3))

-- 4. Frage Welche Nummer und welchen Namen haben die Artikel

select anr, aname
from artikel 
        where anr in(select anr 
            from lieferung
            where datepart (mm,ldatum) = 8
            and datepart (yyyy,ldatum) = 1990
            and lnr in (select lnr from lieferung group by lnr having count(lnr) >= 3))

/*
Gesucht ist das Lieferdatum der Lieferungen wo Hamburger Lieferanten
rote und blaue Artikel geliefert haben.
*/

select ldatum
from lieferung
where lnr in (select lnr
             from lieferant
             where lstadt = 'Hamburg'
             and anr in (select anr from artikel where farbe in('rot','blau')))

-- oder 

select convert(char(10),ldatum,104) as [Lieferdatum]
from lieferung
where lnr in (select lnr
             from lieferant
             where lstadt = 'Hamburg')
             and anr in (select anr from artikel where farbe in('rot','blau'))

insert into lieferung values('L04','A04',500,'09.08.90');
insert into lieferung values('L04','A03',500,'09.08.90');

/*
Gesucht sind die Namen und Nummern der Artikel deren letzte Lieferung
an dem Tag war als auch Artikel A02 zuletzt geliefert wurde.
*/

select anr, aname 
from artikel
where anr in(select anr from lieferung
             group by anr
             having max(ldatum) = (select max(ldatum)
                                  from lieferung
                                  where anr = 'A02'));

/*
Nummern und Namen der Lieferanten die jeden Artikel geliefert haben.
*/

select lnr, lname
from lieferant 
where lnr in(select lnr from lieferung)
            
    

select lnr, lname
from lieferant 
where lnr in(select lnr 
             from lieferung
             group by lnr
             having count(distinct anr) = (select count(anr)
             from artikel));

-- delete artikel where anr > 'A06' 

/* Nummern und Namen von Artikel die mindestens zweimal geliefert wurden, 
von Lieferanten die ebenfalls mehr als zweimal geliefert haben.
*/

select anr, aname
    from artikel
    where anr in(select anr
                from lieferung
                group by anr
                having count(anr) >=2)

--oder

select anr, aname
    from artikel
    where anr in (select anr
                 from lieferung
                 where lnr in(select lnr from lieferung group by lnr having count(lnr) > 2)
                 group by anr
                 having count(anr) >=2)

--Unterabfragen in der SELECT -Liste

select anr, aname, gewicht,
        gewicht -(select avg(gewicht) from artikel) as [Abweichung vom Durchschnitt]
from Artikel;

-- korrelierte Unterabfragen

-- langsamste Art von Unterabfragen
-- fast jede korrelierte Unterabfrage kann in eine einfache Unterabfrage
-- oder in einen Join umgewandelt werden.

-- im Gegensatz zu einfachen Unterabfragen beginnt eine korrelierte
-- Unterabfrage mit der auesseren Abfrage

-- Lieferanenten die mindestens dreimal geliefert haben

select *
from lieferant as a
where 3 <= (select count(lnr)
            from lieferung as b
            where a.lnr = b.lnr);
-- oder

select *
from lieferant
where 3 <= (select count(lnr)
            from lieferung
            where lieferant.lnr = lieferung.lnr);

-- delete lieferung where datepart(yyyy,ldatum) > 1990;

-- Alle Angaben zu Lieferanten die geliefert haben

select *
from lieferant as a
where exists (select *
            from lieferung as b
            where a.lnr = b.lnr);

-- oder

select *
from lieferant
where exists (select *
              from lieferung
              where lieferant.lnr = lieferung.lnr);

---------------------------------------------------------------------

TAG 6:

use standard
go 

-- loeschen
-- delete lieferant where lnr > 'L05';
-- delete lieferung where lmenge = 500 or datepart(yyyy,ldatum) > 1990;

select * 
from lieferant cross join lieferung;

-- kartesisches Produkt wir immer groesser je mehr cross joins ausgefuehrt werden

select * 
from lieferant cross join lieferung cross join artikel 
cross join lieferant as a 
cross join lieferung as b 
cross join artikel as c

-- INNER JOINS

-- liefert alle Datensaetze der am Join beteiligten Tabellen die die
-- Verknuepfungsbedingungen erfuellen

-- Lieferanten mit ihren Lieferungen

select *
from lieferant join lieferung on lieferant.lnr = lieferung.lnr;

-- oder 

select *
from lieferant as a join lieferung as b on a.lnr = b.lnr;

-- im  dargstellten Ergebnis besteht eine Redundanz an Tabellenspalten (lnr)
-- wenn die entfernt wird sprechen wir ueber einen NATURAL Join

select a.lnr, lname, status, lstadt, anr, lmenge, ldatum
from lieferant as a join lieferung as b on a.lnr = b.lnr;

-- die Lieferungen Hamburger Lieferanten im August 1990

select a.lnr, lname, status, lstadt, anr, lmenge, ldatum
from lieferant as a join lieferung as b on a.lnr = b.lnr
where lstadt = 'Hamburg'
and datepart(mm,ldatum) = 8 
and datepart(yyyy,ldatum) = 1990;

-- Nummern und Namen der Lieferanten die geliefert haben

select a.lnr, lname
from lieferant as a join lieferung as b on a.lnr = b.lnr

-- Im Ergebnis erscheinen 12 Datensaetze. Einige sind identisch.

select *
from lieferant as a join lieferung as b on a.lnr = b.lnr

-- aus der logischen Menge des Joins zwischen Lieferant und Lieferung
-- lasse ich mir die Spalten lnr und lname anzeigen

-- wie entferne ich die doppelten DS -- mit DISTINCT

select distinct a.lnr, lname
from lieferant as a join lieferung as b on a.lnr = b.lnr

-- wenn bei einem Join nur die Spalten einer der am Join beteiligten
-- Tabellen angezeigt werden, dann benoetige ich DISTINCT

-- Nummern, Namen und Lieferdatum der roten und blauen Artikel
-- die von Lieferanten aus Ludwigshafen geliefert wurden

select a.anr, aname, ldatum
from artikel as a join lieferung as b on a.anr = b.anr
    join lieferant as c on b.lnr = c.lnr
where farbe in ('rot','blau')
and lstadt = 'Ludwigshafen';

-- Joins eignen sich hervorragend fuer Unterabfragen in der
-- FROM -Klausel

-- Nummern, Namen und Anzahl ihrer Lieferungen fuer alle Lieferanten
-- die  mindestens 2x geliefert haben

select a.lnr, lname, anz as [Anzahl Lieferung]
from lieferant as a join (select lnr, count(*) as [anz]
                          from lieferung
                          group by lnr) as b on a.lnr = b.lnr
where anz >= 2;

-- 1. korrelierende Unterabfrage 

select lnr, lname
from lieferant
where exists (select *
               from lieferung
               where lieferant.lnr = lieferung.lnr);    --langsam

-- 2. einfache Unterabfrage 

select lnr, lname
from lieferant
where lnr in (select lnr from lieferung);               --schneller

-- 3. Join Abfrage 

select distinct a.lnr, lname
from lieferant as a join 
lieferung as b on a.lnr = b.lnr;                        --am schnellsten

-------

-- hinter jedem Join steht ein kartesisches Produkt
-- darum ist folgende Anweisung falsch!

-- die Nummern und Namen der Lieferanten die noch nie geliefert haben

select distinct a.lnr, lname
from lieferant as a join 
lieferung as b on a.lnr <> b.lnr;           -- falsches Ergebnis

-- bei naeherer Betrachtung enthaelt das Ergebnis 48 DS, 60 DS des
-- kartesischen Produktes minus 12 DS die logisch zusammen gehoeren

select * 
from lieferant as a join lieferung as b
    on a.lnr <> b.lnr

-- die oben genannte Fragestellung kann man trotzdem mit
-- einem JOIN beantworten

-- es wird ein OUTER Join benoetigt- --> die Fragestellung wird etwas spaeter
-- wieder aufgenommen

-- aufnehmen eines Testdatensatz --> eine Lieferung fuer die es keinen
-- Lieferanten gibt
-- das laesst das Datenbanksystem micht zu --> referentielle Integritaet
-- darum muessen wir tricksen

alter table lieferung drop constraint lnr_fs;
go 

insert into lieferung values('L33','A05',500,getdate());
go 

alter table lieferung with nocheck
add constraint lnr_fs foreign key(lnr) references lieferant(lnr);
go

-------

-- linker OUTER Join

-- gesucht sind alle Lieferanten mit ihren Lieferungen und auch die
-- Lieferanten die noch nicht geliefert haben

select *
from lieferant as a left join lieferung as b on a.lnr = b.lnr

-- rechter OUTER Join

-- gesucht sind alle Lieferanten mit ihren Lieferungen und die
-- Lieferungen denen kein Lieferant zugeordnet werden kann

select *
from lieferant as a right join lieferung as b on a.lnr = b.lnr

-- voller OUTER Join

-- gesucht sind alle Lieferanten mit ihren Lieferungen, weiterhin 
-- die Lieferanten die noch nicht geliefert haben und die
-- Lieferungen denen kein Lieferant zugeordnet werden kann

select *
from lieferant as a full join lieferung as b on a.lnr = b.lnr

-- also zurueck zur Frage: Nummern und Namen der Lieferanten 
-- die noch nicht  geliefert haben

select a.lnr,lname
from lieferant as a left join lieferung as b on a.lnr = b.lnr
where b.lnr is null;

 ---------------------------------------------------------------

 TAG 7:

 Übung 5:

 1. 

 -- die Daten aller Lieferanten aus Ludwigshafen?

 select *
 from Lieferant 
 where lstadt = 'Ludwigshafen'

 2.

 -- die Nummern, Namen und Lagerorte aller gelieferter Artikel

 select distinct a.anr, aname, astadt
 from artikel a, lieferung b
 where a.anr = b.anr;

 3.

 -- die Nummern und Namen aller Artikel und ihr Gewicht in kg

 select anr, aname, gewicht * 0.001 as [kg]
 from artikel;

 4. 

 -- die Namen aller Lieferanten aus Aachen mit einem Statuswert 
 -- zwischen 20 und 30

 select lname 
 from lieferant
 where lstadt = 'Aachen' and status between '20' and '30'

 5.

 -- die Nummern und Namen aller Artikel, deren Gewicht 
 -- 12, 14 oder 17 Gramm betraegt

 select anr, aname
 from artikel
 where gewicht in ('12','14','17')

 6.

 -- die Daten aller Lieferungen von Lieferanten aus Hamburg 

 select *
 from lieferung
 where lnr in (select lnr
              from lieferant
              where lstadt = 'Hamburg')

 7. 

-- Artikelnummern, Artikelname und Lieferantennummern und Lieferantennamen 
-- mit uebereinstimmenden Lagerort und Wohnort

 select anr,aname,lnr,lname 
 from artikel join lieferant on astadt = lstadt;

 8.

 -- Artikelnummer, Artikelname und Lagerort aller gelieferten Artikel 
 -- und Lieferantennummer Lieferantenname 
 -- und Wohnort des jeweiligen Lieferanten,
 -- sofern Lagerort und Wohnort uebereinstimmen

 select anr, aname, astadt, lnr, lname, lstadt
 from artikel, lieferant
 where astadt = lstadt
 and anr + lnr in (select anr +lnr
                   from lieferung)

 9.

 -- Paare von Artikelnummern, von Artikeln mit gleichem Lagerort 
 -- (Jedes Paar soll nur einmal ausgegeben werden)

 select a.anr, b.anr
 from artikel a, artikel b
 where a.astadt = b.astadt
 and a.anr < b.anr;

 10.
 
 -- Nummern aller Lieferanten, die mindestens einen Artikel geliefert
 -- haben den auch Lieferant 'L03' geliefert hat

  select lnr 
  from lieferung
  where anr in (select anr 
                from lieferung
                where lnr = 'L03')
  and lnr <> 'L03';

 11.

 -- Nummern aller Lieferanten, die mehr als einen Artikel geliefert haben

   select lnr 
   from lieferung
   group by lnr
   having count(distinct anr) > 1;
 
 12.

 -- Nummern und Namen der Artikel, die am selben Ort wie Artikel A03
 -- gelagert werden

   select anr, aname
   from artikel
   where anr = 'A03'

   -- besser

   select anr, aname
   from artikel
   where astadt = (select astadt
                   from artikel
                   where anr = 'A03')
   and anr <> 'A03'

 13.

 -- durchschnittliche Liefermenge des Artikels A01

   select avg(lmenge)
   from lieferung
   where anr = 'A01' 

 14.

 -- Gesamtliefermenge aller Lieferungen des Artikels A01 durch den Lieferanten
 -- L02

   select sum(lmenge)
   from lieferung
   where anr = 'A01' and lnr = 'L02'
  
 15.

 -- Lagerorte der Artikel, die von Lieferant L02 geliefert wurden

   select astadt 
   from artikel a, lieferung b
   where a.anr = b.anr
   and lnr = 'L02';

 16. 

 -- Nummern und Namen der Lieferanten, deren Statuswert kleiner als 
 -- der von Lieferant L03 ist

   select lnr, lname
   from lieferant
   where status  < (select status 
                    from lieferant 
                    where lnr = 'L03')

 17.
 
 -- Nummern von Lieferanten, welche die gleichen Artikel wie 
 -- Lieferant L02 geliefert haben
 
   select distinct lnr 
   from lieferung a
   where lnr <> 'L02'
   and not exists    (select * 
                      from lieferung b
                      where lnr = 'L02'
                      and not exists   (select * 
                                        from lieferung c
                                        where c.lnr = a.lnr
                                        and c.anr = b.anr));
                                    
 18.

 -- die Namen aller Orte die Lager Ort von Artikeln oder Wohnort 
 -- von Lieferanten sind

    select astadt as [Lagerort bzw. Wohnort]
    from artikel
    union
    select lstadt 
    from lieferant;       

 19.

 -- Nummern und Namen aller Lieferanten, die nicht den Artikel A05 
 -- geliefert haben

    select lnr, lname 
    from lieferant 
    where lnr not in (select lnr
                      from lieferung
                      where anr = 'A05');
                                      
 20.

 -- Lieferantennummern und Namen der Lieferanten, die alle Artikel 
 -- geliefert haben

    select lnr, lname
    from lieferant
    where lnr in  (select lnr
                   from lieferung
                   group by lnr
                   having count(distinct anr) = (select count(*) from artikel));

 21.

 -- Nummern, Namen und Wohnort der Lieferanten, die bereits geliefert 
 -- haben und deren Statuswert groesser als
 -- der kleinste Statuswert aller Lieferanten ist

    select distinct a.lnr, lname, lstadt
    from lieferant a, lieferung b
    where a.lnr = b.lnr
    and status > (select min (status) from lieferant);

 22.

 -- Nummern und Bezeichnung aller Artikel, deren durchschnittliche Liefermenge 
 -- kleiner als die des Artikels A03 ist

    select a.anr, aname
    from artikel a, lieferung b
    where a.anr = b.anr
    group by a.anr, aname
    having avg (lmenge) < (select avg (lmenge)
                            from lieferung
                            where anr = 'A03');

 23.

 -- Lieferantennummern, Lieferantenname, Artikelnummer und 
 -- Artikelbezeichnung aller Lieferungen, die seit dem 05.05.1990
 -- von Hamburger Lieferaanten durchgefuehrt
 -- wurden

    select a.lnr, lname, b.anr, aname
    from lieferant a join lieferung b on a.lnr = b.lnr join artikel 
    c on b.anr = c.anr
    where lstadt = 'Hamburg'
    and ldatum >= '05.05.1990';

24. 
 
 -- Anzahl der Lieferungen, die seit dem 05.05.1990 von Hamburger Lieferanten
 -- durchgefuehrt wurden

    select count(*)
    from lieferant a, lieferung b
    where a.lnr = b.lnr
    and lstadt = 'Hamburg'
    and ldatum >= '05.05.1990';

 25.

 -- Ortsnamen, die Wohnort aber nicht Lagerort sind

    select distint lstadt
    from lieferant
    where lstadt not in     (select astadt
                             from artikel);

26.

 -- Ortsnamen, die sowohl Wohnort als auch Lagerort sind

    select distint lstadt
    from lieferant, artikel
    where lstadt = astadt;

---------------------------------------------------------------

TAG 8:

  --pruefen mit

 select * from lieferant

 -- Daten bearbeiten

 -- Insert

 -- Einen Datensatz in eine Tabelle einfuegen

 -- 1. in der Reihenfoolge der Tabellendefinition

 insert into lieferant values('L20','Krause',5,'Erfurt');

 -- 2. geaenderte Reihenfolge

 insert into lieferant(lstadt,lnr,status,lname) values('Weimar','L21',5,'Schulze');

 insert into lieferant values('Erfurt','L22','Krause',5,) -- Fehler

 -- 3. unbekannte Werte

 insert into lieferant values('L22','Maria',5,null);

 insert into lieferant (lnr,lname) values('L23','Horst');

 -- das geht nur wenn fuer alle Spalten die nicht ausgegeben werden, NULL
 -- Marken zugelassen sind

 -- BLOB laden (binary large objects)

 create table medien 
 (nr int not null,
 bild varbinary(max) null,
 typ varchar(5) null);

 -- pruefen

 select * from medien

insert into medien values
(1,(select * from openrowset(bulk 'c:\xml\colonel.jpg', single_blob) as c), '.jpg');

-- weiter Moeglichkeiten zum Massenladen

select *
into lieferung_hist
from lieferung;

insert into lieferung_hist select * from lieferung;

--pruefen mit

select * from lieferung_hist

-- Datenaenderung mitschneiden

create table spion
(lfdnr int,
wann datetime,
wer sysname,
was varchar(20),
primaerschluessel char(3),
neuer_wert char(100),
alter_wert char(100));

insert into lieferant
output 1,getdate(),suser_name(),'Insert', inserted.lnr, inserted.lnr, null
       into spion
values('L24','Boomer',5,'Weimar')

-- pruefen mit

select * from spion

-- aendern der Daten

-- Daten werden geaendert mit der UPDATE Anweisung wenn
-- ein oder mehrere Spaltenwerte einer oder mehrerer Datensaetze
-- geaendert werden

-- eine Update - Anweisung ohne where Klausel macht keinen Sinn

-- die Maria zieht nach Gotha

update lieferant
set lstadt = 'Gotha'
where lnr = 'L22';

-- der Status der Lieferanten die mehr als zwei mal geliefert haben 
-- soll um 5 Punkte erhoeht werden

update lieferant
set status = status + 5
where lnr in(select lnr
             from lieferung
             group by lnr
             having count(lnr) > 2);

-- mit Output arbeiten

-- bei einer Update Anweisung werden 2 logische Tabellen gebildet
-- inserted --> mit dem neuen geaenderten Wert
-- deleted --> mit alten ungeaenderten Wert

-- der Lieferant L23 zieht nach Urbich (weil Weltstadt)

update lieferant
set lstadt = 'Urbich'
output 2, getdate(), suser_name(), 'Update', 
        inserted.lnr, inserted.lstadt, deleted.lstadt
into spion
where lnr = 'L23';

-- pruefen mit

select * from spion

-- der Lieferant 23 zieht ploetzlich nach Dittelstedt

update lieferant
set lstadt = 'Dittelstedt'
output 3, getdate(), suser_name(), 'Update', 
        inserted.lnr, inserted.lstadt, deleted.lstadt
into spion
where lnr = 'L23';

-- DELETE

-- loescht einen oder mehrere Datensaetze
-- sollte nicht ohne where Klausel verwendet werden

-- L23 verlaesst fluchtartig die Firma

delete lieferant
output 4, getdate(),suser_name(),'Delete',deleted.lnr,null,deleted.lnr
into spion
where lnr= 'L23'

-- Alle Lieferanten ausser L05, die nicht geliefert haben sollen gloescht 
-- werden

delete lieferant
where lnr not in (select lnr from lieferung)
and lnr <> 'L05';

-- Loeschen von Datensaetzen einer Tabelle ohne Protokolierung

truncate table lieferung;

select * from lieferant

---------------------------------------------------------------------------------

Tag 9:

-- Installieren von SQL Server --

-- das Produkt ist in der Express, Standart, Developer und Evaluierungsedition
-- erhaeltlich

-- die express Edition ist kostenfrei
-- es gibt Einschränkungen in der Groesse
-- der Datenbanbkdateien und es gibt
-- keine Moeglichkeit der hohen Verfügbarkeit, der
-- Automatisierung und der Ueberwachung

-- die Evaluierungsversion entspricht der Enterprise Edition
-- alle Funktionen sind verfügbar
-- laeuft in der Regel nach 100 Tagen ab

-- die Developer Edition entspricht der Microsoft
-- Edition, darf aber nur fuer die Entwicklung eingesetzt
-- werden

-- die Standard Edition unterstuetzt nicht alle 
-- Funktionen der hohen Verfügbarkeit und des Audit

-- SQL Server unterstuetzt RAID 1, RAID 5, RAID 10

-- arbeiten mit dezidierten Platten --> Datendateien und
-- Protokolldateien niemals auf ein Device

-- die Dienstkonten sollten nicht die lokalen (vorinstallierten) sein
-- auch wenn der SQL Server auf einem lokalen (ohne Domäne) Rechner installiert wird 
-- sollten Konten erstellt werden mit einem sicheren Kennwort

-- installieren sie nur die Dienste die sie umbedingt benoetigen

-- wir wollen den SQL Server 2016 Enterprise Edition ohne grafische Oberflaeche installieren
-- es ist jeweils ein Device fuer die Datenbankdateien und die Datenbankprotokolldateien
-- vorhanden, das gleiche gilt fuer die TEMPDB

use master
go

-- Datenbanken erstellen und Verwalten

-- Typen
-- Systemdatenbanken (master, msdb, tempdb, model, distribution)


-- Transaktion ist eine unteilbare Einheit die entweder ganz oder
-- ganz garnicht ausgeführt wird

-- Beispiel: der Herr Beinlich hat für den Herrn Donath
--				ein Programm geschrieben für das Homebanking
--				Herr Donath will 5000 Euro von seinem Girokonto
--				auf sein Sparkonto ueberweisen

-- Datenbank erstellen

create database standard;
go

exec sp_helpdb standard;

create table lieferant
(
lnr char(3) not null, 
lname nvarchar(200) not null,
status tinyint null,
lstadt nvarchar(200) null
);
go


create table artikel
(
anr char(3) not null,
aname varchar(200) not null,
farbe varchar(10) null,
gewicht decimal(5,2) null,
astadt nvarchar(200) not null,
amenge int not null
);
go

create table lieferung
(
lnr nchar(3) not null, 
anr nchar(3) not null, 
lmenge int not null,
ldatum datetime not null
);
go

--------------------------------------------------------------------------

TAG 10:

insert into dbo.lieferant values('L01', 'Schmidt', 20, 'Hamburg');
insert into dbo.lieferant values('L02', 'Jonas', 10, 'Ludwigshafen');
insert into dbo.lieferant values('L03', 'Blank', 30, 'Ludwigshafen');
insert into dbo.lieferant values('L04', 'Clark', 20, 'Hamburg');
insert into dbo.lieferant values('L05', 'Adam', 30, 'Aachen');



insert into dbo.artikel values('A01', 'Mutter', 'rot', 12, 'Hamburg', 800);
insert into dbo.artikel values('A02', 'Bolzen', 'grün', 17, 'Ludwigshafen', 1200);
insert into dbo.artikel values('A03', 'Schraube', 'blau', 17, 'Mannheim', 400);
insert into dbo.artikel values('A04', 'Schraube', 'rot', 14, 'Hamburg', 900);
insert into dbo.artikel values('A05', 'Nockenwelle', 'blau', 12, 'Ludwigshafen', 1300);
insert into dbo.artikel values('A06', 'Zahnrad', 'rot', 19, 'Hamburg', 500);



insert into dbo.lieferung values('L01', 'A01', 300, '18.05.90');
insert into dbo.lieferung values('L01', 'A02', 200, '13.07.90');
insert into dbo.lieferung values('L01', 'A03', 400, '01.01.90');
insert into dbo.lieferung values('L01', 'A04', 200, '25.07.90');
insert into dbo.lieferung values('L01', 'A05', 100, '01.08.90');
insert into dbo.lieferung values('L01', 'A06', 100, '23.07.90');
insert into dbo.lieferung values('L02', 'A01', 300, '02.08.90');
insert into dbo.lieferung values('L02', 'A02', 400, '05.08.90');
insert into dbo.lieferung values('L03', 'A02', 200, '06.08.90');
insert into dbo.lieferung values('L04', 'A02', 200, '09.08.90');
insert into dbo.lieferung values('L04', 'A04', 300, '20.08.90');
insert into dbo.lieferung values('L04', 'A05', 400, '21.08.90');

--pruefen mit

select * from lieferant
select * from lieferung
select * from artikel

-----------------------------------------------------------------------

-- Einschränkungen für Tabellen erstellen
-- primary key, unique, foreign key, default, check
-- sie dienen dazu Integritätsbedingungen innerhalb der
-- Datenbank durchzusetzen
-- diese Einschränkungen koennen für Tabellen mit und ohne DS erstellt
-- werden
-- sind in den Tabellen bereits Datensaetze enthalten, dann müssen sie
-- die Einschränkung erfüllen 

-- einige Einschraenkungen (primary key, unique) erzeugen Indizes

-- Primaerschluessel

alter table lieferant add constraint lnr_pk primary key(lnr);
 
-- pruefen mit

exec sp_help 'lieferant'

-- standardmaessig erzeugt der Primaerschluessel einen clustered 
-- (gruppierten) Index

-- Test

insert into lieferant values('L01','Kummer',5,'Erfurt'); -- L01 vorhanden
insert into lieferant values('L06','Kummer',5,'Erfurt',0); -- geht

-- Unique (Vorbereitung)

alter table lieferant add vers_nr varchar(20) null;

update lieferant set vers_nr = 'ABC-12345-CC' where lnr = 'L01';
update lieferant set vers_nr = 'DEF-12345-CC' where lnr = 'L02';
update lieferant set vers_nr = 'GHI-12345-CC' where lnr = 'L03';
update lieferant set vers_nr = 'JKL-12345-CC' where lnr = 'L04';
update lieferant set vers_nr = 'MNO-12345-CC' where lnr = 'L05';
update lieferant set vers_nr = 'MNO-12345-CC' where lnr = 'L06';

alter table lieferant add consraint versnr_unq unique(vers_nr)

-- Test 

insert into lieferant values ('L07','Jach',5,'Erfurt','ABC-12345-CC') -- Fehler
insert into lieferant values ('L07','Jach',5,'Erfurt','QRS-12345-CC'); -- geht

-- fuer eine Tabelle kann es mehr als eine Unique Einschraenkung geben
-- Unique laesst null Marken zu ( nur eine )
-- Unique erstellt standardmaessig einen nonclustered Index

-------

-- Spalte vers_nr loeschen
-- 1. das Constraint loeschen

alter table lieferant drop constraint versnr_unq;

-- 2. Tabellenspalten loeschen

alter table lieferant drop drop column vers_nr;

-- Default
-- wenn fuer eine Spalte kein Wert angegeben wird soll ein Defaultwert gelten.
-- auf Primaerschluesselspalten werden keine Default erstellt

alter table lieferant add constraint lstadt_def default 'Gotha' for lstadt;

-- test

insert into lieferant values ('L06','Kulesch',5, default);
insert into lieferant (lnr,lname,status) values ('L08','Schoeppach',5);


exec sp_help 'lieferant'
select * from lieferant

-- wenn eine NULL Marke aufgenommen werden muss, dann muessen sie diese
-- explizit angegeben werden

insert into lieferant values ('L09','Warnecke',5, null);

-- Check Einschränkung

-- mit dieser Einschraenkung kenne gültige Werte fuer eine Tabellenspalte 
-- festgelegt werden
-- pro Spalte kann es keine, eine oder mehrere Check Einschraenkungen geben
--		      sie sollten sich nicht gegenseitig blockieren oder aufheben
-- Check Einschraenkungen koennen sich auch auf andere Spalten der Tabelle 
-- beziehen Beispiel: im Datensatz befindet sich ein Wert 'Name' und 'Vorname'
--		      es soll sichergestellt werden, dass wenn nur der Vorname 
--                    angegeben wurde, das Einfuegen des DS abgewiesen wird


-- Lieferantennamen sollen mit einem Buchstaben beginnen

alter table lieferant add constraint lname_chk check(lname like '[A-Z]%');

insert into lieferant values ('L10','8Sell',5, Jena); -- Fehler Name beginnt mit Zahl

insert into lieferant values ('L10','Sell',15, default);

-- der Statuswert darf nur zwischen 0 und 100 liegen
 
 alter table lieferant add constraint status_chk check(status between 0 and 100);

insert into lieferant values ('L11','Sell',105,'Erfurt');  -- Fehler

insert into lieferant values ('L11','Sell',99,'Erfurt');


-- Fremdschluessel ( foreign key)

alter table lieferung add constraint lnr_fk foreign key(lnr) 
						  references lieferant(lnr)
						  on update cascade;

alter table lieferung add constraint anr_fk foreign key(anr) 
						  references artikel(anr);  
                                                 
                                                  -- erzeugt einen Fehler weil
						  -- die Tabelle Artikel
						  -- noch keinen Primaerschluessel
						  -- besitzt

alter table artikel add constraint anr_pk primary key(anr);	


alter table lieferung add constraint anr_fk foreign key(anr)
					  references artikel(anr);	    
                                          
                                                  -- jetzt sollte es gehen


-- Primaerschluessel fuer die Tabelle Lieferung

-- zusammengesetzter Primaerschluessel aus dem Spalten lnr, anr, ldatum

alter table lieferung add constraint lief_pk primary key(lnr,anr,ldatum);

--  Beispiel fuer referentielle Integritaet (hat was mit dem foreign key zu tun)

insert into lieferung values('L44','A02',500, GETDATE());

--	Fehler wegen referentieller Integritaet, den Lieferanten L44
--	gibt es nicht !!!

-- Opertationregel kaskadierndes aendern zwischen Lieferant und Lieferung

select * from lieferant as a join lieferung as b on a.lnr = b.lnr
where a.lnr = 'L04';

update lieferant set lnr = 'L06' where lnr = 'L04';

select * from lieferant as a join lieferung as b on a.lnr = b.lnr
where a.lnr = 'L04';		
                                -- leer weil L04 nicht mehr vorhanden

select * from lieferant as a join lieferung as b on a.lnr = b.lnr
where a.lnr = 'L06';		
                                -- dem Liefranten wurde die lnr
				-- geaendert und seine Lieferungen wurden
				-- ihm wieder zugeordnet


exec sp_help 'lieferant'
select * from lieferant
delete lieferant
where lnr = 'L11'


alter table lieferung drop constraint lief_pk;

alter table lieferung alter column lnr char(3) not null;
alter table lieferung alter column anr char(3) not null;

-----------------------------------------------------------------------------

Tag 12:

-- Dateigruppen erstellen

use master
go

-- 1. Dateigruppen (Aktiv, Passiv und Indexe) erstellen

alter database standard add filegroup passiv;
go

alter database standard add filegroup aktiv;
go

alter database standard add filegroup indexe;
go

-- 2. Datenbankdateien erstellen und den entsprechenden Dateigruppen 
--	  zuordnen.

alter database standard 
add file (name = standard_passiv,
			filename = 'j:\db.daten1\standard_passiv.ndf',
			size = 20 GB,
			maxsize = 25 GB,
			filegrowth = 5%) to filegroup passiv;

alter database standard 
add file (name = standard_aktiv,
			filename = 'k:\db.daten2\standard_aktiv.ndf',
			size = 20 GB,
			maxsize = 25 GB,
			filegrowth = 5%) to filegroup aktiv;

alter database standard
add file (name = standard_index,
			filename = 'l:\indexe\standard_index.ndf',
			size = 10 GB,
			maxsize = 20 GB,
			filegrowth = 1 GB) to filegroup indexe;

-- Damit Datenbankbenutzer die berechtigt sind in der Datenbank
-- Tabellen, Sichten, Prozeduren oder Funktionen zu erstellen, diese nicht
-- aus Versehen in der Dateigruppe PRIMARY erstellen, machen wir
-- jetzt die Dateigruppe Passiv zur Default Dateigruppe

alter database standard modify filegroup passiv default;
go

-- wunsch von Herrn Ruhland
-- Maxsize von der Datei in PRIMARY und des Transaktionsprotokol
-- aendern

-- pruefen mit

exec sp_helpdb standard;

alter database standard
modify file (name = standard,
			 maxsize = 20 GB);
go

alter database standard
modify file (name = standard_log,
			 maxsize = 15 GB);
go

-- Tabelle in die entsprechende Dateigruppe verschieben
-- Tabellen koennen nur in eine andere Dateigruppe verschoben werden in dem
-- der gruppierte Index (Primaerschluessel) geloescht wird und sofort wieder
-- neu erstellt wird und ihm der Dateigruppenname zugewiesen wird

-- die Tabellen Lieferant und Artikel nach 'Passiv' verschieben


use standard
go

-- Primaerschluessel loeschen

alter table lieferung drop constraint lnr_fk;

alter table lieferung drop constraint anr_fk;

-- 1. Tabelle Lieferant

alter table lieferant drop constraint lnr_pk;
go

alter table lieferant add constraint lnr_pk primary key(lnr) on passiv;


-- 2. Tabelle Artikel

alter table artikel drop constraint anr_pk;
go

alter table artikel add constraint anr_pk primary key(anr) on passiv;


-- 3. Tabelle Lieferung

alter table lieferung drop constraint lief_pk;
go

alter table lieferung add constraint lief_pk primary key(lnr,anr,ldatum) on aktiv;

-- Fremdschluessel

alter table lieferung add constraint lnr_fk foreign key(lnr)
			references lieferant(lnr) on update cascade;
go

alter table lieferung add constraint anr_fk foreign key(anr)
			references artikel(anr);
go

exec sp_help lieferant;

--------------------------------------------------------------------

TAG 13:

Übung 6
 
use master
go
create database forschung
on primary
	(name = forschung_sk,
	filename = 'e:\daten\forschung_sk.mdf',
	size = 20MB,
	maxsize = 50MB,
	filegrowth = 5%),
filegroup aktiv
	(name = forschung_daten1,
	filename = 'f:\daten\forschung_daten1.ndf',
	size = 20MB,
	maxsize = 50MB,
	filegrowth = 10MB),
filegroup passiv
	(name = forschung_daten2,
	filename = 'g:\daten\forschung_daten2.ndf',
	size = 50MB,
	maxsize = 200MB,
	filegrowth = 5%)
log on
	(name = forschung_log,
	filename = 'j:\protokoll\forschung_log.ldf',
	size = 7MB,
	maxsize = 25MB,
	filegrowth = 5%);
go



alter database forschung
modify filegroup passiv default;
go

use forschung;
go

create table orte
(ortid int not null constraint ortid_ps primary key,
plz char(5),
ortsname nvarchar(100),
constraint orte_unq unique(plz,ortsname));
go

-- Stammdatensaetze Orte fuer die Abteilungen

insert into orte values(1,'98527','Suhl');
insert into orte values(2,'99082','Erfurt');
insert into orte values(3,'99423','Weimar');
insert into orte values(4,'07743','Jena');
insert into orte values(5,'99868','Gotha');
insert into orte values(6,'99734','Nordhausen');
insert into orte values(7,'99610','S�mmerda');
go

create table abteilung
(abt_nr char(3) not null constraint abt_nr_ps primary key
			  constraint abt_nr_chk check((abt_nr like 'a[1-9][0-9]'
			  or abt_nr like 'a[1-9]')
			  and cast(substring(abt_nr,2,2) as integer) between 1 and 50),
 abt_name nchar(50) not null constraint abt_name_chk check(abt_name like '[A-Z]%'),
 ortid int not null constraint aortid_fs references orte(ortid)
					constraint aortid_chk check(ortid in(1,2,3,4,5,6,7)));
go

insert into abteilung values('a1','Forschung',1);
go

create table projekt
(pr_nr char(4) not null constraint pr_nr_ps primary key 
			 constraint pr_nr_chk check((pr_nr like 'p[1-9][0-9][0-9]'
			 or pr_nr like 'p[1-9][0-9]'
			 or pr_nr like 'p[1-9]')
			 and cast(substring(pr_nr,2,3) as integer) between 1 and 150),
 pr_name nchar(50) not null constraint pr_name_chk check(pr_name like '[A-Z]%'),
 mittel money not null constraint mittel_chk check(mittel between 1 and 2000000));
go

insert into projekt values('p1','Mondlandung', 600000);
go

create table mitarbeiter
(m_nr integer not null identity(1000,1) constraint m_nr_ps primary key,
 m_name nchar(50) not null constraint m_name_chk check(m_name like '[A-Z]%'),
 m_vorname nchar(50) null constraint m_vorname_chk check(m_vorname like '[A-Z]%'),
 ortid int not null constraint mortid_fs references orte(ortid),
 strasse nchar(100)null constraint strasse_chk check(strasse like '[A-Z]%'),
 geb_dat date null,
 abt_nr char(3) null constraint abt_nr_fs references abteilung(abt_nr)
								  on update cascade);
go

insert into mitarbeiter values('M�ller','Bernd',1,'Hochheimer Stra�e 2',
							   '18.09.1999', 'a1');
go

create table arbeiten
(m_nr integer not null constraint m_nr_fs references mitarbeiter(m_nr)
									on update cascade,
 pr_nr char(4) not null constraint pr_nr_fs references projekt(pr_nr)
									on update cascade ,
 aufgabe nchar(200) null constraint aufgabe_chk check(aufgabe like '[A-Z]%'),
 einst_dat date not null constraint einst_dat_chk 
							 check(einst_dat >= dateadd(dd,-7,getdate())),
 constraint arbeiten_ps primary key(m_nr,pr_nr)) on aktiv;
go

insert into arbeiten values(1000,'p1','Organisator',getdate());
go

create table telefon
(m_nr integer not null constraint m_nr_fk references mitarbeiter(m_nr)
									on update cascade,
 vorw char(10) not null,
 tel_nr char(10) not null,
constraint tel_ps primary key(vorw, tel_nr));
go

insert into telefon values(1000, '0361', '563399');
go

Übung Ende

--------------------------------------------------------------------------

TAG 14

/* Datenbankobjekte um Abfragen effektiver einzusetzen und
schneller zu machen

-Sichten
-Indizes
-Transact SQL Stapelprogramme
-Cursor
-gespeicherte Prozeduren
-benutzerdefinierte Funktion
-Trigger

*/

-- Views (gespeicherte Abfragen)
-- Vorteil die Abfrage wird bei der ersten Ausführung kompiliert
--		und der Ausfuehrungsplan in den Prozerdurcache gelegt.
--		jeder weiter Aufruf der Sicht verwendet den bereits kompilierten
--		Ausfuehrungsplan

-- eine Sicht ermöglicht eine horizontale und vertikale Partionierung von
-- Tabelleninfos
-- Beispiel: Der Meister des Meisterbereichs 2 soll nur die Mitarbeiter
--		angezeigt bekommen die in seinem Meisterbereich arbeiten (horizontal)
--		aber ohne die Spalte 'Gehalt' (vertikal)

-- Sichten werden mit create view .. erstellt, mit alter view ... geaendert
-- und mit drop view .. geloescht

-- die create view - Anweisung darf nicht mit anderen SQL Anweisungen in einem
-- Stapel stehen! mit 'go' seperieren

create view hamb_lief
as
select lnr, lname, lstadt
from lieferant
where lstadt = 'Hamburg';
go

-- wo werden Sichten gespeichert?

select * from sys.objects where object_id = object_id('hamb_lief');
select * from sys.views where object_id = object_id('hamb_lief');

-- wo liegt die Sichtdefinition

select * from sys.sql_modules where object_id = object_id('hamb_lief');

--oder

exec sp_helptext 'hamb_lief';

select * from hamb_lief;
go

-- view definition verschluesseln

alter view hamb_lief
with encryption
as
select lnr, lname, lstadt
from lieferant
where lstadt = 'Hamburg';
go
 
 --pruefen mit

exec sp_helptext 'hamb_lief';

-- rueckgaengig mit

alter view hamb_lief
as
select lnr, lname, lstadt
from lieferant
where lstadt = 'Hamburg';
go

--  Sichten mit Join

create view lieflief
as
select a.lnr, lname, status, lstadt, anr, lmenge, ldatum
from lieferant as a join lieferung as b on a.lnr = b.lnr;
go

select * from lieflief;
go
, 
-- Datenaenderung ueber Sichten (Insert, Update, Delete)

-- Datenaenderungen auf Sichten die sich auf mehr als eine Tabelle beziehen
-- sind nicht moeglich oder nur mit INSTEAD - Trigger moeglich

--Insert

insert into hamb_lief values('L30','Kirsten','Hamburg');

select * from hamb_lief;
select * from lieferant;

insert into hamb_lief values('L31','Meier','Weimar');


select * from hamb_lief;
select * from lieferant;

-- Sicht aendern with check option

alter view hamb_lief
as
select lnr, lname, lstadt
from lieferant
where lstadt = 'Hamburg'
with check option;
go


insert into hamb_lief values('L32','Lauch','Weimar');  --Fehler

insert into hamb_lief values('L32','Lauch','Hamburg'); -- Geht

----

create view hamb_lief1
as
select lnr, lname
from lieferant
where lstadt = 'Hamburg'
with check option;
go

select * from hamb_lief1;

insert into hamb_lief1 values('L33','Maria','Hamburg');  -- geht nicht

insert into hamb_lief1 values('L33','Maria');		 -- geht nicht

-- Update

update hamb_lief
set lstadt = 'Erfurt'
where lnr = 'L32';				-- Fehler wegen der with check option

update hamb_lief
set lname = 'Kaltduscher'
where lnr = 'L32';				-- geht


select * from hamb_lief;

/*
was wurde in der Datenbank gemacht

update lieferant
set lname = 'Kaltduscher'
where lnr = 'L32'				-- kommt von Update
and lstadt = 'Hamburg';			        -- kommt von der Sicht
*/

-- DELETE

-- niemals ohne where - Klausel  
-- weil
-- delete hamb_lief;			        -- loescht alle Hamburger
--						-- Lieferanten

delete hamb_lief
from hamb_lief as a left join lieferung as b on a.lnr = b.lnr
where b.lnr is null;

-- loescht alle Hamburger Lieferanten ohne Lieferung

select * from Hamb_lief;

----------------------------------------------------------------------

TAG 15:

use standard
go

create table indtest
(id int not null,
namen varchar(100) not null,
vname varchar(100) null,
ort varchar(200) not null);
go

declare @x int = 1;
while @x <= 1000000
begin
	insert into indtest 
	values(@x, cast(@x as varchar(10)) + 'Warmduschwer',
			'Max_' + cast(@x as varchar(10)),
			cast(@x as varchar(10)) + '_Suhl_' + cast(@x as varchar(10)));
	set @x +=1;
	--set @x = @x +1;
end;
go

----

select count(*) from indtest;

select * from indtest;

select * from sys.indexes where object_id = object_id('indtest)';

-- Fragmentierungsgrad des Haufens

select * from
sys.dm_db_index_physical_stats(db_id(),object_id('indtest'),null,null,null);


-- eine Tabelle kann maxsimal 1000 Indizes besitzen
-- 1 gruppierten Index und 999 nicht gruppierte Indizes

-- Besitzt eine Tabelle keinen gruppierten Index bleiben die Daten in der
-- Speicherorganisationsform 'Haufen'


create index vname_ind on indtest(vname);

-- welche Indizes gibt es fuer die Tabelle

select * from sys.indexes where object_id = object_id('indtest)';

-- Fragmentierungsgrad des Haufens

select * from
sys.dm_db_index_physical_stats(db_id(),object_id('indtest'),null,null,null);

select * from indtest where vname like '%3099%';

-- sobald ein gruppierter Index erstellt wird, wird die physische Reihenfolge
-- der Datensaetze entsprechend der indizierten Reihenfolge geaendert

-- Primaerschluessel fuer die Tabelle Indtest

alter table indtest add constraint id_pk primary key(id);

select * from indtest where vname like '%3099%';

select * from indtest where id between 3055 and 10344;

----

-- welche Indizes gibt es fuer die Tabelle

select * from sys.indexes where object_id = object_id('indtest)';

-- Fragmentierungsgrad des Haufens

select * from
sys.dm_db_index_physical_stats(db_id(),object_id('indtest'),null,null,null);

----

select astadt
from artikel
where aname = 'Schraube' and astadt like '%m%';

-- zusammengesetzter Index

create index aname_astadt_ind on artikel(aname,astadt);

select aname, astadt, amenge
from artikel
where farbe = 'rot';

-- abgedeckter Index (der Index deckt die Abfgrage vollstaendig ab)

create index farbe_art on artikel(farbe, aname, astadt, amenge);

-- Index mit eingeschlossenen Spalten
-- wird verwendet wenn die Anzahl der Spalten des zusammengesetzten Index
-- 16 Spalten überschreitet und/oder die Laenge der Spaltenwerte groesser
-- 900 Byte ist.

create index farbe_art_inc on artikel(farbe) include (aname, astadt, amenge);

select aname, astadt, amenge
from artikel
where farbe = 'rot';

-- damit ist der zusammengesetzte Index ueberfluessig und kann geloescht werden

drop index artikel.farbe_art;

select * from artikel

-- Extras SQL Server Profiler 

-- Indexfragmentierung
-- die Fragmentierung von Indizes stellen Sie mit der dynamischen Verwaltungs-
-- funktion sys.de_db_indexphysical_stats() fest
-- wichig dabei ist die Spalte avg_fragmentation_in_percent

-- bei Fragmetation bis 30 % wird der Index neu Organisiert

alter index farbe_art_inc on artikel reorganize;

-- bei Fragmentation ueber 30 % wird der Index neu gebildet

alter index farbe_art_inc on artikel rebuild;

----

use standard;
go

-- Programmieren mit Tranact "SQL"

-- Begriffe:
-- Script -- ist eine Datei welche mit der Endung .sql abgespeichert wird
-- Stapel .. ein Script besteht aus einem oder mehrern Stapel
--		ein Stapel endet mit einem Stapelzeichen "go"
--		eine Variable welche in einem Stapel deklariert wurde kann in
--		einem anderen Stapel nicht verwendet werden -- sie ist nicht bekannt

-- Anweisungsbloecke
-- werden verwendet in einer WHILE - Schleife, im IF und ELSE Zweig einer
-- IF/ELSE - Anweisung und im Body von benutzerdefinierten Funktionen

begin
	select @@version;
	select * from lieferant
end;

-- Meldungen
-- einfache Meldungen mit PRINT
-- Print gibt nur Zeichenfolgen zurück

print 'Heute ist' + datename(dw,getdate()) + 
	  'der' + convert(char(10),getdate(),104)

-- Meldungen mit raiserror
-- mit raiserror koennen benutzerdefinierte Meldungen, Systemmeldungen
-- und AdHoc - Meldungen verwendet werden

-- Systemmeldungen und benutzerdefinierte Meldungen werden in sys.messages
-- gespeichert

select * from sys.messages where language_id = 1031;


-- benutzerdefinierte Meldungen beginnen bei der messages_id > 50000
-- Raiserrormeldungen besitzen einen Schweregrad
--  1 - 10 -- einfache Fehler die vom Benutzer behoben werden
-- 11 - 18 -- komplexere Fehler die teilweise vom Benutzer behoben werden koennen
-- 19 - 25 -- schwerwiegende Fehler des Systems, koennen nur von sysadmins behoben
	   -- werden und muessen ins Ereignisprotokoll von Windows geschrieben werden
-- 20 - 25 -- trennt den Client vom Server

-- Meldung ertellen

exec sp_addmessage 600000, 10,'Cant deleted!','us_english', 'false';
exec sp_addmessage 600000, 10,'Kann nicht geloescht werden!','german', 'false';

-- Meldung verwenden

raiserror(600000,10,1);				-- Meldung
raiserror(600000,13,1);				-- Fehler 600000
raiserror(600000,21,1) with log;	        -- schwerer Fehler

-- sie koennen Raiseerrror mit jedem Schweregrad ins Ereignisprotokoll
-- eintragen lassen;

raiserror(600000,13,1) with log;	-- Fehler 600000 im Ereignisprotokoll

-- AdHoc - Meldungen

raiserror('Heute ist Donnerstag.',10,1);

use standard 
go

-- Variable
-- der Inhalt einer Variablen steht nur innerhalb der Stapel zur Verfuegung
-- in dem die Variable deklariert wurde

-- Deklaration

declare @ort varchar(50), @farbe varchar(10), @nummer char(3)
declare @kuchen xml;
declare @erg table(nummer char(3),
				   namen varchar(50),
				   lagermenge int);

-- Wertzuweissung

-- 1. Werte fuer skalare Variablen 

set @ort = 'Hamburg';
set @farbe = 'rot';
set @nummer = 'A03';

-- 2. Werte durch Abfrage

select @ort = astadt, @farbe = farbe from artikel where anr = @nummer;

set @kuchen = '<rezept>			
				<mehl>500</mehl>	
				<eier>4</eier>
				<zucker>200</zucker>
				</rezept>';

insert into @erg select anr, aname, amenge from artikel where astadt = @ort;

-- Variableninhalt anzeigen lassen

select @ort as [Ortsvariable], @farbe as [Farbe], @nummer as [Artikelname];

-- zu 2tens 

print 'Der Artikel' + ' (' + @nummer + ') ist ' + @farbe + ' und lagert in ' + @ort;

-- xml

select @kuchen;

-- Tabellenvariable

select * from @erg;
go

use standard
go

-- Sprachkonstukte

-- IF/ELSE

declare @tab sysname = 'zitrone'
if not exists(select * from sys.tables where object_id = object_id(@tab))
begin	
	raiserror('Die Tabelle gibt es nicht.',10,1,@tab);
	return;
end
go

----

declare @datum datetime = '11.06.2022';
if @datum >= dateadd(dd, -7, getdate())
begin
	raiserror('Datum ist im Bereich.',10,1);
end;
else
begin
	raiserror('Datum ist zu gross.',10,1);
end;
go

-- neu im Angebot

drop table if exists zitrone;

-- Schleifen

declare @x int = 1;
while @x <=10
begin
	print cast(@x as varchar(10)) + '.Durchfall.';
	set @x +=1;
end;


-- Try -- CATCH

begin try
	begin 
		select 1/0;
	end
end try
begin catch
	begin
		select ERROR_NUMBER() as [Fehlernummer],
			   ERROR_MESSAGE() as [Fehlertext],
			   ERROR_SEVERITY() as [Schweregrad];
	end
end catch
go

-- und

begin try
	begin
		begin transaction erdbeere
		update lieferant set lstadt = 'Erfurt';
		select 1/0;
		commit transaction erdbeere
	end
end try
begin catch
	begin
		rollback transaction erdbeere
		select ERROR_NUMBER() as [Fehlernummer],
			   ERROR_MESSAGE() as [Fehlertext],
			   ERROR_SEVERITY() as [Schwerergrad]
		end
end catch;
go

----

use standard
go

-- Dynamische SQL Anweissungen

declare @tab sysname, @nr char(3), @spalte1 sysname, @spalte2 sysname
set @nr = 'A03';
set @tab = 'artikel';
set @spalte1 = 'aname';
set @spalte2 = 'astadt';

-- select @spalte1, @spalte2 from @tab where anr = @nr;

-- in der FROM - Klausel darf nur ein Tabellenname oder eine Tabellenvariable stehen
-- der Abfrageoptimierer stellt fest das eine Variable in der FROM - Klausel steht,
-- sie aber nicht als Variable deklariert wurde.

-- wir benoetigen eine dynamische SQL Anweisung. diese wird erst zur Laufzeit 
-- aufgebaut und mit execute ausgefuehrt.

-- den Abfragestring koennen sie einer Variablen uebergeben oder direkt
-- im EXECUTE definieren

-- exec('select' + @spalte1 + ',' +@spalte2 + 'from' + @tab + 'where anr =' + @nr);

-- declare @sql varchar(max)
-- set @sql = 'select' + @spalte1 + ', ' + @spalte2 + 'from' + @tab + 'where anr = ' + @nr;
-- select @sql;


declare @tab sysname, @nr char(3), @spalte1 sysname, @spalte2 sysname
set @nr = 'A03';
set @tab = 'artikel';
set @spalte1 = 'aname';
set @spalte2 = 'astadt';
declare @sql varchar(max), @hk char(1) = char(39);
set @sql = 'select ' + @spalte1 + ', ' + @spalte2 + 
		   ' from ' + @tab + ' where anr = ' + @hk + @nr + @hk;
exec(@sql);
go

----------------------------------------------------------------------------------

TAG 16

use standard
go

-- alter database standard modify file (name = standard,
									 -- maxsize =20 GB);
-- go

-- alter database standard modify file (name = standard_log,
									 -- maxsize =10 GB);
-- go

if db_name() in('master','tembdb','msdb','model')
begin
	raiserror('Sie befinden sich in einer Systemdatenbank.',10,1);
	return;
end;

declare @realsize bigint = 0, @maxsize bigint = 0, @name varchar(2000);

declare filegroesse cursor for
select name, size, max_size from sys.database_files;

-- alles zusammmen auswaehlen

open filegroesse;

fetch from filegroesse into @name, @realsize, @maxsize;
while @@fetch_status = 0
begin
	if((@realsize * 8196 / 1024) * 100 / (@maxsize * 8196 / 1024)) >= 20 
		begin
		dbcc shrinkfile(@name) with no_infomsgs;
			if((@realsize * 8196 / 1024) * 100 / (@maxsize * 8196 / 1024)) >= 20 
			  raiserror('Die Datei %s konnte nicht verkleinert werden.',10,1,@name);
			else
			  raiserror('Die Datei %s wurde verkleinert.',10,1,@name);
		end
	else
		 raiserror('Die Datei %s musste nicht verkleinert werden.',10,1,@name);

	fetch from filegroesse into @name, @realsize, @maxsize;
end;
deallocate filegroesse;
go

-----
Uebung 7

/*
Schreiben sie ein Skript welches ihnen fuer jede Tabelle
der aktuellen Datenbank den Tabellennamen und die Anzahl der
Datensaetze dieser Tabelle in einem Tabellenergebnis, mit den
Spalten "Tabellenname" und "Anzahl Datensaetze" ausgibt
*/

-- bevorzugtes Ergebnis

declare @ausgabe table(Tabellenname varchar(200), Anzahl_Datensätze int);
declare @anz table (anzahl int);
declare @tabelle sysname, @sql varchar(max);

declare tab_such cursor for 
select b.name + '.' + a.name 
from sys.tables as a join sys.schemas as b
on a.schema_id = b.schema_id
where a.name not like 'sys%';

open tab_such;
fetch tab_such into @tabelle;

while @@fetch_status = 0
begin                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        
	delete @anz;
	set @sql = 'select count(*) from '+  @tabelle;
	insert into @anz exec(@sql);
	insert into @ausgabe values (@tabelle, (select anzahl from @anz)); 
	fetch tab_such into @tabelle;
end;
select * from @ausgabe;
deallocate tab_such;
go

-- funktioniert aber Herr Lohse war nicht begeistert

SELECT o.name, i.rowcnt
FROM sysindexes AS i
INNER JOIN sysobjects AS o
ON  i.id = o.id
WHERE i.indid < 2
AND OBJECTPROPERTY(o.id, 'IsMSShipped') = 0
ORDER BY o.name

-- oder so, aber Herr Lohse ist immer noch nicht begeistert

SELECT o.name, ddps.row_count
FROM sys.indexes AS i
INNER JOIN sys.objects AS o
ON i.OBJECT_ID = o.OBJECT_ID
INNER JOIN sys.dm_db_partition_stats AS ddps
ON i.OBJECT_ID = ddps.OBJECT_ID
AND i.index_id = ddps.index_id
WHERE i.index_id < 2
AND o.is_ms_shipped = 0
ORDER BY o.name

------

Uebung 8:

declare @tabname sysname = 'artikel', @indname varchar(100) = 'anr_pk';

/*
Schreiben sie ein Skript welches für die oben angegebene Tabelle und den
angegebenen Indexname den Fragmentierungsgrad des Index ermittelt.
Ist der Fragmentierungsgrad unter 7 % soll nichts passieren. Ist der
Fragmentierungsgrad zwischen 8 und 30 % soll der Index reorganisiert 
werden, ist der Fragmentierungsgrad über 30 % soll der Index neu
gebildet werden.
*/

use standard;
go

declare @tabname sysname = 'artikel', @indname varchar(100) = 'anr_ps';

-------

declare @tabvoll sysname, @indid int;

select @tabvoll = a.name + '.' + b.name 
from sys.schemas as a join sys.tables as b 
on a.schema_id = b.schema_id 
where b.name = @tabname and b.name  not like 'sys%';

if not exists(select * from sys.objects where object_id = object_id(@tabname))
  begin
	raiserror('Die Tabelle %s gibt es nicht in der Datenbank.',10,1,@tabname);
	return;
  end;
else if not exists (select * from sys.indexes where name = @indname)
	  begin
		raiserror('Einen index mit dem Namen %s gibt es nicht.',10,1,@indname);
		return;
	  end;

select @indid = index_id from sys.indexes where name = @indname;

if (select avg_fragmentation_in_percent
    from 
	sys.dm_db_index_physical_stats(db_id(),object_id(@tabvoll),@indid, null,null)) < 7
begin
	raiserror('Index %s nicht fragmentiert.',10, 1, @indname);
end;
if (select avg_fragmentation_in_percent
	from 
	sys.dm_db_index_physical_stats(db_id(),object_id(@tabvoll),@indid, null,null)) between 8 and 30
begin
	execute ('alter index ' + @indname + ' on ' + @tabvoll + ' reorganize;');
	raiserror('Index %s ist leicht fragmentiert. er wurde reorganisiert',10, 1, @indname);
end;
if (select avg_fragmentation_in_percent
	from 
	sys.dm_db_index_physical_stats(db_id(),object_id(@tabvoll),@indid, null,null)) > 30
begin
	execute ('alter index ' + @indname + ' on ' + @tabvoll + ' rebuild;');
	raiserror('Index %s ist stark fragmentiert. er wurde neu gebildet',10, 1, @indname);
end;
go


Tag 17:


use standard
go

-- Programieren von Scripten

-- ein Script besitzt die Endung .sql es kann manuell ueber den SSMS oder ueber
-- SQL CMD gestartet werden. Aussserdem kann ein Script in Auftraege des Betriebssystem
-- eingebunden werden und durch diese gestartet werden

-- Grundlegender Umgang bei der Arbeit mit Variablen

-- 1. eine Variable muss deklariert werden
-- 2. danach wird die Variabe mit Werten gefuellt 
--			- dazu verwendet man SET oder die SELECT Anweissung in Verbindung mit
--			- Sprachkonstrukten der Sprache TQSL
--					-IF/ELSE, Anweissungsbloecke. WHILE, TRY and CATCH
--					-raiseerror, print, return
-- 3. Anzeigen und Ausgeben des Inhalts der Variablen 
-- eine normale Variable muss nicht Vernichtet werden, da sie nach dem GO im Stapel
-- nicht mehr existiert

-- eine Variable vom Typ Cursor wird deklariert, geoeffnet, mit fetch durchsucht,
-- mit Close geschlossen und mit deallocate vernichtet
-- ein Cursor wird immer dann verwendet, wenn fuer eine Menge von Ergebnissen
-- fuer jede einzelne Teilmenge ein Entscheidung getroffen werden muss
-- Beispiel: Ermitteln aller Daten und Protokolldateien einer Datenbank feststellen
--			der Groesse jeder Datei, und die Datei vekleinern wenn eine kritische 
--			Groesse erreicht wurde

-------

-- Dynamische SQL Anweisungen

-- Beispiel:
-- 1. select spalte, spalte from tabelle where spalte = @wert, GEHT IMMER
-- 2. select @spvar, @spvar from @tabvar where @spvar = @wert; ES WIRD EINE DYNAMISCHE 
--															   ABFRAGE BENOETIGT.

declare @sp1 sysname, @sp2 sysname, @tab sysname, @wert int = 0;
declare @sql varchar(max);
set @sp1 = 'aname';
set @sp2 = 'amenge';
set @tab = 'artikel';
set @wert = 300;

-- Wie es nicht geht

select @sp1 from @tab where @sp2 >= @wert;  -- SO GEHT ES NICHT!!

-- Wie es geht

execute('select ' + @sp1 + ' from ' + @tab + ' where ' + @sp2 + ' >= ' + @wert);

						-- aufpassen auf Leerzeichen!!!!!!!

-- ueberpruefen mit 

declare @sp1 sysname, @sp2 sysname, @tab sysname, @wert int = 0;
declare @sql varchar(max);
set @sp1 = 'aname';
set @sp2 = 'amenge';
set @tab = 'artikel';
set @wert = 300;


set @sql = 'select ' + @sp1 + ' from ' + @tab + ' where ' + @sp2 + ' >= '
					+ cast(@wert as varchar(200));
select @sql;

--oder

exec(@sql);
go
						
--------

-- gespeicherte Systemprozeduren

exec sp_help 'lieferant';
exec sp_help;
go

-- Benutzerdefenierte gespeicherte Prozeduren

-- eine Prozedur kann KEINEN, EINEN oder MEHRERE Parameter uebernehmen
-- im Koerper einer Prozedur koennen mehrere Anweisungen enthalten sein 
-- eine Prozedeur kann weitere Prozeduren aufrufen. 
-- die Verschachtelungsebene sarf 32 nicht ueberschreiten 
-- feststellen in welcher Ebene ich mich befinde mit @@nestlevel

-- gespeicherte Prozeduren koennen auch mit CLR ( Common Language Runtime)
-- erstellt werden, als Assembley im SQL Seerver bekannt gemacht werden
-- und aus dem Assembly mit create procedure.. eine gespeicherte Prozedur erstellen
-- CLR --> .NET farhige Programmierung

-- Vorteile
-- 1. die modulare Programmierung SQL Code wird zu einer Einheit kompiliert
-- 2. die Geschwindigkeit: nach dem ersten Ausfuehren der Prozedur wird der 
--    kompilierte Ausfuehrungsplan in den Prozedurcache abgeleget und jede erneute 
--    Ausfuehrung greift nur noch auf den Prozedurcache zurueck
-- 3. Reduzierung des Netzwerkverkehrs
-- 4. Verwendung als Sicherheitsmechanismus. Werden Informationen aus kritischen
--    Umgebungen (Internet) direkt in die Datenbank gespeichert sollte dazu
--    eine Prozedur zwischengeschaltet werden. Plausibilitaetspruefung

use standard
go 

-- gespeicherte Prozeduren erstellen

create procedure mathe
as
declare @zahl1 float, @zahl2 float, @erg float;
set @zahl1 = 3.896;
set @zahl2 = 12.006;

set @erg = @zahl1 / @zahl2;
print 'Ergebnis:   ' + cast(@erg as varchar(100));
go

-- Prozedur starten

exec mathe;
go

-----------

-- Parameteruebergabe an die Prozedur

create procedure mathe1 @zahl1 float, @zahl2 float
as
declare @erg float;

set @erg = @zahl1 / @zahl2;
print 'Ergebnis:   ' + cast(@erg as varchar(100));
go

exec mathe1 12.88,19.7;
go

-------------

-- Parametervariablen der Prozedeur mit Default - Werten belegen

create procedure mathe2 @zahl1 float = 1, @zahl2 float = 1
as
declare @erg float;

set @erg = @zahl1 / @zahl2;
print 'Ergebnis:   ' + cast(@erg as varchar(100));
go

exec mathe2 12.88,19.7; 

exec mathe2 12.88; 

exec mathe2;

exec mathe2 default, 34.99;

go

-- die Prozedur soll das berechnete Ergebnis an das aufrufende Programm zuruekgeben


create procedure mathe3 @zahl1 float = 1, @zahl2 float = 1, @erg float output
as
set @erg = @zahl1 / @zahl2;
go

-- Aufruf

declare @ergebnis float
exec mathe3 5.88, 2.66, @ergebnis output;
print 'Ergebnis:   ' + cast(@ergebnis as varchar(100));
go

-- Fehlerhafte Parameterwerte verhindern

create procedure mathe4 @zahl1 float = 1, @zahl2 float = 1, @erg float output
as
if @zahl2 = 0
begin
	raiserror('Du sollst nicht teilen durch NULL, du Horst!',10,1);
end;
set @erg = @zahl1 / @zahl2;
go

---

declare @ergebnis float
exec mathe4 5.88, 0, @ergebnis output;
print 'Ergebnis:   ' + cast(@ergebnis as varchar(100));
go

exec mathe 4 13
go

-- Die Prozedur gibt einen Return - Wert zurueck

create procedure mathe5 @zahl1 float = 1, @zahl2 float = 1, @erg float output
as
if @zahl2 = 0
begin
	return 8;
end;
set @erg = @zahl1 / @zahl2;
go

---

declare @ergebnis float, @rw int;
exec @rw = mathe5 5.88, 0, @ergebnis output;
if @rw = 8
raiserror('Du sollst nicht teilen durch NULL, du Horst!',10,1);
else
print 'Ergebnis:   ' + cast(@ergebnis as varchar(100));
go

/*
wir schreiben eine Prozedur welcher eine Farbe eines Artikels uebergeben wird.
Die Prozedur soll mir den Artikelname, Artikelnummer und den Lagerort 
der Artikel mit der angegebenen Farbe anzeigen bzw zurueckgeben.
(Erweiterung: wird keine Farbe übergeben sollen alle Artikel angezeigt werden)
*/

-- einfache Abfrage

select anr, aname, astadt
from artikel 
where farbe = 'rot';
go

-- Prozedur erstellen ( Ergebnis anzeigen)

create procedure farb_art @farbe varchar(10)
as
select anr, aname, astadt
from artikel 
where farbe = @farbe;
go

exec farb_art 'rot';
go

-- das Ergebnis anzeigen und den Übergabe Paramter temporaer stellen

alter procedure farb_art @farbe varchar(10) = null
as
if @farbe is not null
begin
	raiserror('Artikel fuer die Farbe %s.',10,1,@farbe)
	select anr, aname, astadt
	from artikel 
	where farbe = @farbe;
end;

if @farbe is null
begin
	raiserror('Artikel ueber alle Farben.',10,1,@farbe)
	select anr, aname, astadt
	from artikel;	
end;
go

exec farb_art 'blau';
exec farb_art;

-- die Prozedur soll  das Ergebnis an das aufrufende Programm zurueckgeben
-- 1. mit einer permanenten Tabelle

-- Tabelle erstellen

create table art_ergebnis
(Artikelnummer char(3),
Artikelname varchar(300),
Lagerort varchar(200));

-- Tabelle füllen

insert into art_ergebnis exec farb_art 'rot';

-- Tabelle abrufen

select * from art_ergebnis;
go

-- 2. mit einer Tabellenvariablen

declare @erg table (Artikelnummer char(3),
				   Artikelname varchar(300),
				   Lagerort varchar(200));
insert into @erg exec farb_art 'rot';
select * from @erg;
go

------

Uebung 9:

use standard;
go

/*
Schreiben Sie eine Prozedur "obj_anz" der optional ein Datenbankobjektname- Bezeichener
übergeben wird.
Gültige Bezeichener (Objektnamen) sind : Tabelle, Sicht, Prozedur.
Wird der Prozedur kein Bezeichner übergeben soll die Prozedur die Anzahl 
der Tabellen, der Sichten und der Prozeduren anzeigen.
Wird ein Bezeichner übergeben soll nur die Anzahl des angegebenen Bezeichners
angezeigt werden.

Verwenden für die Anzeige eine Tabellenvariable.
Die Angaben zu den Objekten finden Sie in der Systemsicht sys.objects und
nähere Infos in der Spalte Type.
*/

create procedure obj_anz @bezeichner varchar(200) = null
as
if @bezeichner is not null 
   and @bezeichner not in('tabelle','sicht','prozedur')
  begin
  raiserror('Folgende Parameterwerte sind zulässig: Tabelle; Sicht; Prozedur.',10,1);
  return;
  end
declare @ausgabe table(Objekttyp nvarchar(50), Anzahl int); 

if @bezeichner is null
  begin
	select case when type = 'u' then 'Tabellen'
						when type = 'v' then 'Sichten'
						when type = 'p' then 'Prozeduren'
						end as [Objekttyp], isnull(COUNT(*),0) as [Anzahl]
	from sys.objects
	where type in('u','v','p') and name not like 'sys_%'
	and name not like 'sp_%' and name not like 'fn_%'
	group by type;
  end;

if @bezeichner is not null
begin
if @bezeichner = 'sicht'
  begin
	insert into @ausgabe values('Sichten',
					(select count(*) from sys.objects where type = 'v'));
	select * from @ausgabe;
  end;
if @bezeichner = 'tabelle'
  begin
	insert into @ausgabe values('Tabellen',
					(select count(*) from sys.objects where type = 'u'
									  and name not like 'sys_%'));
	select * from @ausgabe;
  end;
if @bezeichner = 'prozedur'
  begin
	insert into @ausgabe values('Prozeduren',
					(select count(*) from sys.objects where type = 'p'
									  and name not like 'sp_%'));
	select * from @ausgabe;
  end;

end;
go

--------

exec obj_anz;
exec obj_anz 'Sicht';


--------------------------------------------

TAG 18:

Uebung 10:

use standard
go

/*

SQL Server

21. Juni 2022

Aufgabe

Schreiben Sie eine gespeicherte Prozedur welche den Fragmentierungsgrad der
Indizes, der Tabellen der Datenbank Standard, überprüft und die Indizes bei Bedarf
defragmentiert.
Der Prozedur soll der Name der Tabelle und der Name eines Indexs übergeben
werden. Der Name der Tabelle muss auf jeden Fall der Prozedur übergeben werden,
der Indexname ist eine optionale Eingabe.
Wird der Prozedur kein Indexname übergeben muss jeder Index der angegebenen
Tabelle auf Fragmentierung überprüft werden und bei einem festgestellten
Fragmentierungsgrad entsprechend behandelt werden.
Wird ein Indexname angegeben dann soll nur dieser spezielle Index auf
Fragmentierung überprüft werden und entsprechend behandelt werden.
Es gilt, ist der Fragmentierungsgrad unter 8% soll mit dem Index nichts passieren. Ist
der Fragmentierungsgrad zwischen 8% und 30% (Grenzen einschließlich) soll der
Index reorganisiert werden.
Liegt der Fragmentierungsgrad über 30% soll der Index neu gebildet werden.

Je nachdem was die Prozedur für dem jeweiligen Index macht (Nichts, Reorganisieren
oder Neu bilden), soll eine entsprechende Raiserror- Meldung (Schweregrad 10) für
den Anwender der Prozedur generiert werden. Außerdem soll die Prozedur über eine
geeignete Parameter- und Fehlerüberprüfung verfügen,

Speichern Sie die fertige Prozedur im Datenaustausch, Ordner "SQL", Unterordner
"Prozedur Indexdefrag" mit der Namenskonvention <Proz Ihr_ Name>.sql ab.
Ich wünsche Ihnen viel Erfolg.

*/

-- Prozedur Index Defragmentieren.sql

use standard;
go
create procedure ind_defr @tab nvarchar(200), @ind varchar(200) = null
as
declare @obj_id int, @ind_id int, @ind_name nvarchar(200)

if not exists(select * from sys.objects where object_id = object_id(@tab))
	begin
		raiserror('Die Tabelle %s gibt es nicht in der Datenbank.',10,1,@tab)
		return
	end
if @ind is null
	begin
		declare tab_ind cursor for
		select object_id, index_id, name from sys.indexes where object_id = object_id(@tab)
		open tab_ind
		fetch tab_ind into @obj_id, @ind_id, @ind_name
		while @@fetch_status = 0
			begin
					if (select avg_fragmentation_in_percent
					from sys.dm_db_index_physical_stats(db_id(),object_id(@tab),@ind_id,null,null)) < 13
				begin
					raiserror ('Index %s nicht fragmentiert.',10,1,@ind_name)
				end
				if (select avg_fragmentation_in_percent
					from sys.dm_db_index_physical_stats(db_id(),object_id(@tab),@ind_id,null,null))between 13 and 30
				begin
					execute ('alter index ' + @ind_name + ' on ' + @tab + ' reorganize;')
					raiserror ('Index %s ist leicht fragmentiert. er wurde reorganisiert',10,1,@ind_name)
				end
				if (select avg_fragmentation_in_percent
					from sys.dm_db_index_physical_stats(db_id(),object_id(@tab),@ind_id,null,null)) > 30
				begin
					execute ('alter index' + @ind_name + ' on ' + @tab + ' rebuild;')
					raiserror('Index %s ist stark fragmentiert. er wurde neu gebildet',10,1, @ind_name)
				end
				fetch tab_ind into @obj_id, @ind_id, @ind_name
	end
		deallocate tab_ind
end
if @ind is not null
	begin
		if not exists (select * from sys.indexes where name = @ind)
		begin
			raiserror ('Einen index mit dem namen %s gibt es nicht.',10,1,@ind)
			return
		end
			else
				begin
					select @ind_id = index_id from sys.indexes where name = @ind
					if (select avg_fragmentation_in_percent
					from sys.dm_db_index_physical_stats(db_id(),object_id(@tab),@ind_id,null,null)) < 13
				begin
					raiserror ('Index %s nicht fragmentiert.',10,1,@ind)
				end
				if (select avg_fragmentation_in_percent
					from sys.dm_db_index_physical_stats (db_id(), object_id(@tab),@ind_id, null,null)) between 13 and 30
				begin
					execute ('alter index ' + @ind + ' on ' + @tab + ' reorganize;')
					raiserror ('Index %s ist leicht fragmentiert. er wurde reorganisiert',10,1,@ind)
				end
				if (select avg_fragmentation_in_percent
					from sys.dm_db_index_physical_stats(db_id(),object_id(@tab),@ind_id, null,null)) > 30
				begin				
					execute ('alter index ' + @ind + ' on ' + @tab + ' rebuild;')
					raiserror ('Index %s ist stark fragmentiert. er wurde neu gebildet',10,1,@ind)
				end
		end	
	end
go


-- pruefen mit

exec ind_defr;

exec ind_defr Artikel;

exec ind_defr Artikel, anr_ps;

-- Prozedur loeschen

drop procedure [ind_defr];  
go  

---------------------------------------------------------------------------------

TAG 19:

use standard
go

-- Datenbankschemas erstellen

create schema lager;
go
create schema verkauf;
go

-- Datenbank Tabellen den jeweiligen Schemas zuordnen

alter schema lager transfer dbo.artikel;
go
alter schema verkauf transfer dbo.lieferant;
go
alter schema verkauf transfer dbo.lieferung;
go

-- Was ist passiert?

select * from artikel;			-- dieser Zugriff geht nicht mehr
select * from lager.artikel;	-- funktioniert

-- wenn diese Anweisung geht, dann wurden die Fremdschluessel im
-- Hintergrund richtig umgeschrieben

insert into verkauf.lieferung values('L04','A03',500,getdate());
go

------

-- Berechtigungsverewaltung an Datenbanksystemen speziell am SQL Server

-- die Verwaltung von Berechtigungen erfolt auf drei Ebenen
-- 1. Serverebene (Instanzebene)
-- 2. Datenbankebene
-- 3. Object oder Schemaebene

-- Logins einreichten
-- Es gibt zwei Arten der Authentifizierung

-- Windows Authentifizierung
-- wird verwendet fuer Benutzer (Windowsuser, Windowsgruppen oder Anwendungen)
-- die in der gleichen Domaene arbeiten wie SQL Server
-- es wird nur der Benutzernmame des Logins gespeichert und nicht das Password
-- beim Password vertraut SQL Server dem Active Directorie

-- SQL Server Authentifizierung
-- wird verwendet fuer Logins die sich von ausserhalb der Domaene mit dem
-- SQL Server verbinden muessen

-- die Instanz von SQLServer arbeitet in zwei Modis.
--	1. Nur Windowsauthentifizierung
--	2. gemischte Authentifizierung
--	   dieser Modus kann grafisch oder mit der Prozedur sp_configure festgelegt werden
--     Achtung, danach muss da DBMS gestartet werden


use master;
go


-- Windows Authentifizierung

create login [sql16\verwaltung] from windows;
go
create login [sql16\material] from windows;
go
create login [sql16\diana] from windows;
go

-- der Benutzer Horst darf sich nie mit dem SQL Server verbinden
-- Horst ist Mitglied der Windowsgruppe 'verwaltung' und diese Gruppe
-- hat einen Login in der SQL Server Instanz. Damit hat Horst automatisch
-- auch einen Login.
-- Problemloesung

-- Horst Login erstellen

create login [sql16\horst] from windows;
go

-- und Zugriff verweigern

deny connect sql to [sql16\horst];
go

-- SQL Server Logins

create login [Frank] with Password = 'Pa$$w0rd';
go
create login [Dieter] with Password = 'Pa$$w0rd';
go

-- Erstellen von Serverrollen, zuweisen von Serverberechtigungen
-- arbeit mit festen Serverrollen

-- Diana soll Sysadmin werden

alter server role sysadmin add member [sql16\diana];

-- erstellen einer benutzerdefinierten Serverrolle

create server role useredit;
go


-- Mitglieder der Rolle sollen logins bearbeiten koennen

grant alter any login to useredit;
go

-- der Rolle sollen die Benutzer der Windowsrolle Verwaltung zugewiesen werden

alter server role useredit add member [sql16\Verwaltung];
go

-- weitere Berechtigung fuer die Serverrolle useredit


grant alter any credential to [useredit]
go

----------

-- 2.Ebene Datenbank 

-- Datenbankbenutzer einrichten

use standard;
go

/*
die logins Verwaltung, Material, Frank und Dieter sollen sich mit der 
Datenbank Standard verbinden duerfen
*/

create user verwaltung from login [sql16\verwaltung];
go

-- Standardschema fuer den Datenbankbenutzer Verwaltung festlegen

alter user verwaltung with default_schema = verkauf;
go

create user material from login [sql16\material]
with default_schema = lager;
go

/*
Karl ist Lehrling und darf sich nicht mit der Datenbank Standard verbinden
fuer ihn wird eine Trainingsdatenbank ertstellt in der er DBO ist.
Weiterhin werden 2 Logins (Willi1 und Willi2) bereitgestellt denen er in der 
Trainingsdatenbank Berechtigungen erteilen kann.
*/

-- master

use master
go

create login willi1 with password = 'Pa$$w0rd';
go
create login willi2 with password = 'Pa$$w0rd';
go
create database training;
go

-- Karl den Datenbankzugriff auf standard verbieten und den 
-- Zugriff auf Training erlauben

-- standard

use standard;
go

create user karl from login [sql16\karl];
go
deny connect to karl;
go

-- training

use training;
go

create user karl from login [sql16\karl];
go
alter role db_owner add member karl;
go

use standard;
go

-- benutzerdefinierte Datenbankrolle erstellen

create role dbconfig;
go

-- Berechtigungen zuweisen

grant create view to dbconfig;
go

alter role dbconfig add member material;

--------

create user frank from login frank;
go

create user dieter from login dieter;
go

--------

-- 3. Ebene -- Datenbankobjekte

-- Frank und Dieter sollen SELECT, UPDATE und INSERT Berechtigungen
-- auf die Tabellen Lieferant und Lieferung im Schema  Verkauf erhalten

grant insert, update, select
on schema::verkauf
to frank;

grant insert, update, select
on schema::verkauf
to dieter;

-- Delete fuer die Tabelle Lieferung fuer Frank und Dieter erlauben

grant delete
on verkauf.lieferung
to dieter;

-- den Mitarbeitern von Verwaltung alle Rechte auf die Tabellen
-- Lieferant, Artikel und Lieferung zuweisen

grant insert, update, select, delete
on schema::verkauf
to verwaltung;

grant insert, update, select, delete
on schema::lager
to verwaltung;

------------------------------------------------------------------------

TAG 20:

Uebung 11

/*

Administration SQL Server 2016 - Sicherheit

Sie sind Datenbankadministrator im Verwaltungsbereich einer Supermarktkette und haben die
Aufgabe die Sicherheit fuer den Datenbankserver SQL Server 2016 zu ueberarbeiten.

Alle Mitarbeiter, ausser Mitarbeiter im Aussendienst und Kunden, melden sich an der Domaene
des Unternehmens an. Die neu erstellte Datenbank Donnerstag (Skript ist in ihrem Ordner
DATENAUSTAUSCH\ SQL befindet sich auf einem Server mit dem Namen Ihrer
Standardinstanz und unterstuetzt die Moeglichkeiten von Schemas. Die Tabellen Lieferant und
Artikel befinden sich im Schema Office und die Tabelle Lieferung im Schema Stock.

Sie selbst haben in der Domaene keine Administrativen Berechtigungen vom
Netzwerkadministrator zugewiesen bekommen, besitzen aber ein Login mit Ihrem Namen (in
unserem Fall "Student") in der Domaene und Sie sind lokaler Administrator auf dem Server auf
dem SQL Server installiert ist. Ihnen ist das SA- Passwort bekannt und die Instanz von SQL
Server verwendet die "gemischte Authentifizierung". Eine Sicherheitsrichtlinie im
Unternehmen legt fest, dass alle administrativen Arbeiten unter Ihrem Login und als
SYSADMIN nachvollziehbar sein muessen. Stellen Sie daher sicher dass Sie an der Instanz von
SQL Server als Systemadministrator arbeiten koennen (da Sie das schon sind schreiben Sie nur
die entsprechende Anweisung auf).

Mitarbeiter Ralf, Ihr Stellvertreter wenn Sie im Urlaub oder krank sind, muss in der Lage sein
vorhandene Datenbanken aendern, vergroessern, sichern und wiederherstellen zu koennen. Er
muss ausserdem neue Datenbanken erstellen koennen. Weiterhin muss er die Sicherheit in der
Instanz vollstaendig verwalten koennen. In den vorhandenen Benutzer Datenbanken (Standard
und Donnerstag) arbeitet er als Datenbankbesitzer.

Im Unternehmen gibt es drei Abteilungen: Office, Purchase und Customer Service.
In der Abteilung "Office" arbeiten vier Mitarbeiter: Kerstin Ziegler, Andrea Fischer, Steffen
Drosten und Diana Reichenbach.
In der Abteilung "Customer Service" arbeiten drei Mitarbeiter: Bernd Albrecht, Petra Gutheil,
Albert Ross sowie zwei Azubis Matthias Neuer und Maik Alter.
In der Abteilung "Purchase" arbeiten zwei Mitarbeiter: Jessica Otto und Ute Sitte.
Im Unternehmen sind vier Aussendienstmitarbeiter beschaeftigt: Dieter Acksteiner, Steffi
Reichardt, Anke Grohall und Olaf Schroeter. Diese verbinden sich unregelmaessig mit dem SQL
Server, in der Regel ueber Einwahlpunkte ausserhalb Ihrer Domaene.

In der Windowsdomaene existieren gleichnamige Windowsgruppen wie die Abteilungen, denen
die Mitarbeiter der jeweiligen Abteilung zugeordnet sind.

Der Lehrling darf nicht auf die produktive Datenbank Donnerstag und Standard zugreifen, soll
sich aber im Rahmen seiner Ausbildung mit SQL Server 2016 vertraut machen. Sie erstellen
ihm eine Datenbank "Uebung" und zwei Testanmeldungen willi1 und willi2. Diese Logins soll
er selbst als Datenbankbenutzer in der Datenbank "Uebung" einrichten koennen. Er sollte in die
Lage sein alle Datenbankobjekte in der Datenbank Uebung selbst zu erstellen. Er muss auch
mit den Prozeduren (voller Umfang) von Database Email arbeiten kann.

Alle Mitarbeiter der Firma muessen sich mit der Datenbank Donnerstag verbinden koennen. Die
Mitarbeiter der Abteilung Office besitzen auf die Tabellen Lieferant und Artikel die

Administration SQL Server 2016
Berechtigungen insert, update, delete und select. Auf die Tabelle Lieferung duerfen sie nur
lesend zugreifen.

Die Mitarbeiter der Abteilung Customer Service haben Zugriff, select, insert, update, auf die
Tabelle Lieferung, Sie duerfen aber keine Lieferungen loeschen.

Die Mitarbeiter der Abteilung Purchase muessen neue Artikel aufnehmen koennen, Artikel
aendern koennen und auf alle anderen Tabellen der Datenbank einschliesslich Artikel lesend
zugreifen koennen. Sie muessen weiterhin in die Lage versetzt werden, selbst Sichten zu
erstellen die lesend auf die Tabellen Lieferant und Lieferung zugreifen koennen.

Die Mitarbeiterin Kerstin soll Objekte in der Datenbank aendern koennen und gegebenenfalls
neue Objekte (Tabellen, View, Prozeduren, Funktionen) erstellen. Sie darf aber keine
Datenbanken erstellen oder loeschen duerfen. Weiterhin soll sie alle Anmeldungen an die
Datenbank verwalten koennen.

Die Aussendienstmitarbeiter sollen auf die Tabelle Lieferant Datensaetze lesen, einfuegen und
aendern koennen und Vollzugriff (Insert, Update, Delete, Select) auf die Tabelle Artikel besitzen
sowie lesenden Zugriff auf die Tabelle Lieferung.

Ihre Aufgabe ist es die obenstehende Aufgabe durchzusetzen und in einem Skript fuer das
Serverlogbuch darzustellen.

Speichern Sie Ihre Skripte in der Freigabe "Datenaustausch\SQL\Berechtigungen" ab. 
Im Dateinamen sollte klar Ihr Name zu erkennen sein.

Mein Vorschlag:

ersterbuchstabevorname_nachname_zugriff.sql

Ich wuensche Ihnen viel Erfolg

*/

Loesung

use master;
go

-- Uberprüfen ob ich Systemadmin bin --

select a.role_principal_id, b.name as [Rollenname], a.member_principal_id,
							c.name as [Mitgliedsname]
from sys.server_role_members as a join sys.server_principals as b
on a.role_principal_id = b.principal_id
join sys.server_principals as c
on a.member_principal_id = c.principal_id;

-- Wenn das nicht der Fall ist: Verbinden mit den 5Qt Server als SA --

alter server role sysadmin add member [sql16\student];

-- Danach wieder als Student mit dem 5QL Server verbinden --

--Test- Datenbank und Test- Logins für den Lehrling erstellen:

create database uebung;

go
create login willi1 with password = 'Pa$Sw0rd';
create login willi2 with password = 'Pa$Sw0rd';
go

-- Login und Serverberechtigungen für den Stellvertreter --

create login [sql16\ralf] from windows;
alter server role dbcreator add member [sql16 \ralf];
alter server role diskadmin add member [sql16iralf];
alter server role securityadmin add member [sql16\ralf];

-- Datenbankrollen für den Stellvertreter --
use standard;
go

create user ralf for login [sql16\ralf];
alter role db_owner add member ralf

use urbiworks;
go

create user ralf for login [sql16\ralf];
alter role db_owner add member ralf;
go

use master;

-- Logins für die Abteilungen erstellen --

create login [sqll6\office] from windows;
create login [sql16\custumer _service] from windows;
create login [sql16\Purchase] from windows;

-- Logins für Außendienstmitarbeiter --

create login Acksteiner with password = 'Pa$$w0rd';
create login Reichardt with password = 'Pa$$w0rd';
create login Grohall with password = 'Pa$$w0rd';
create login Schröter with password = 'Pa$$w0rd';
go

----------

-- Zugriff auf Datenbank Urbiworks erteilen --

use UrbiWorks;
go

create user Office from login [sql16\office]
with default_schema = office;

create user Purchase from login [sql16\purchase]
with default_schema = Stock;

create user Kundendienst from login [sql16\custumer_service]
with default_schema = Lager;
go

-- Den Lehrlingen den Zugriff auf die Datenbank UrbiWorks verweigern --

create user Neuer from login [sql16\neuer];
create user [Alter] from login [sql16\alter];
go
deny connect to neuer;
deny connect to [alter];
go

-- Den Lehrlingen den Zugriff auf die Datenbank Standard verweigern --

use standard;
go

create user Neuer from login [sql16\neuer];
create user [Alter] from login [sql16\alter];
go

deny connect to neuer;
deny connect to [alter];
go

-- Für die Lehrlinge die Database Email ermöglichen --
use msdb;
go

create user Neuer from login [sql16\neuer];
create user [Alter] from login [sql16\alter];

alter role databasemailuserrole add member Neuer;
alter role databasemailuserrole add member [Alter];

-- Für die Lehrlinge die Datenbank Uebung vorbereiten --
use uebung
go

create user Neuer from login [sql16\neuer];
create user [Alter] from login [sql16\alter];
go

alter role db_owner add member neuer;
alter role db_owner add member [alter];
go

create user Wil1li1 from login [willi1];
create user Willi2 from login [Willi12];
go

-- Berechtigungen für Kerstin Ziegler --

use master;
go

create login [sql16\Ziegler] from windows;
deny create any database to [sql16\ziegler];
deny alter any database to [sql16\ziegler];
go

use urbiworks;
go

create user Ziegler from login [sql16\Ziegler];
go

alter role db_ddladmin add member ziegler;
grant alter any schema to ziegler;
grant alter any user to ziegler;
go

-- Außendienstmitarbeiter --

create user Acksteiner from login Acksteiner;
create user Reichardt from login Reichardt;
create user Grohall from login Grohall;
create user Schröter from login Schröter;
go

create role aussendienst;
go

alter role aussendienst add member acksteiner´;
alter role aussendienst add member Reichardt;
alter role aussendienst add member grohall;
alter role aussendienst add member schröter;

grant select, insert, update
on office.lieferant to aussendienst;

grant insert, update, delete, delete
on office.artikel to aussendienst;

grant select on schema::stock to aussendienst;

-- Abteilung Office --

grant select, insert, update, delete
on schema::office to Office;

grant select
on schema::stock to Office;
go

-- Abteilung Kundendienst --

grant select, insert, update
on stock.lieferung to kundendienst;
go

-- Abteilung Purchase --

grant insert, update
on office.artikel to purchase;

grant select
on schema::office to purchase;

grant select
on schema::stock to purchase;

grant alter
on schema::stock to purchase
grant create view to purchase;
go

--------------------------------------------------------

TAG 22:


use master
go

-- Sichern und Wiederherstellen von Datenbanken
-- gesichert koennen alle benutzerdefinierten Datenbanken werden und 
-- Systemdatenbanken ausser die tempdb. die tempdb kann deshalb nicht
-- gesichert werden weil sie beim herunterfahren des DBMS geloescht
-- und beim hochfahren neu erstellt wird

-- Datenbanken sollten regelmaessig gesichert werden, egal welches 
-- System der Hochverfuegbarkeit verwendet wird

-- Art und Weise der Sicherungsstrategie ist abhaengig vom 
-- Wiederherstellungsmodel der Datenbank

-- 1. einfaches Wiederherstellungsmodel
--		 bei jedem Checkpoint wird der nicht aktive Teil des Tranaktionsprotokol
--		 abgeschnitten
-- deshalb kann ich in diesem Modell dei Datenbank nur vollstaendig und 
-- differentiell sichern

-- 2. vollstaendiges  Wiederherstellungsmodel
--		 bei einem Checkpoint wird das Protokoll nicht abgeschnitten
--		 vollstaendige, differentielle und Protokollsicherungen sind moeglich
-- in diesem Model ist es moeglich die Datenbank bis zum Ausfallzeitpunkt
-- wiederherzustellen
-- damit das Protokoll nicht vollaueft (Fehler 9002) muss die Datenbank
-- regelmaessig eine Protokollsicherung durchfuehren.
-- Nur bei einer Protokollsicherung wird der nicht aktive Teil des Protokolls
-- abgeschnitten

-- Massenprotolliertes Wiederherstellungsmodel ist eine Ergaenzung des
-- vollstaendigen Wiederherstellungsmodel und wird verwendet 
-- bei Massenkopiervorgaengen (bulk insert, select into ..., insert
-- mit openrowset(), ...)

-- jede Sicherungslinie einer Datenbank beginnt mit einer vollstaendigen Sicherung
-- der Wechsel vom einfachen zum vollstaendigen Wiederherstellungsmodel
-- und umgekehrt unterbricht die Linie

------

use master;
go

-- wohin sichern
-- direckt auf Bandlaufwerk (nicht mehr empfohlen weil alt)
-- eine Netzwerkfreigabe
-- auf eine lokale Festplatte (Device) sichern auf eine Netzwerkfreigabe
-- oder Bandlaufwerk

-- empfohlen wird ein sogenanntes Sicherungsdevice
--			es handelt sich um einen Namen fuer Speicherort
-- Sicherungsdevice erstellen

exec sp_addumpdevice 'disk', 'master_sicher', 'g:\dbbackup\master_sicher.bak';
go

--------

-- Master Datenbank sichern

backup database master to master_sicher with name = 'Master_voll';

-- MSDB wurde grafisch gesichert

-- Datenbank Standard sichern

-- 1. vollstaendige Datenbanksicherung

backup database standard to standard_sicher with name = 'standard_voll';
go

use standard 
go

insert into verkauf.lieferant values('L20','Krause',5,'Erfurt');

-- sichern des Protokolls

backup log standard to standard_sicher with name = 'Protokoll';

---

insert into verkauf.lieferant values('L21','Pausine',5,'Erfurt');

-- sichern des Protokolls

backup log standard to standard_sicher with name = 'Protokoll';

---

insert into verkauf.lieferant values('L22','Mittag',5,'Erfurt');

-- sichern des Protokolls

backup log standard to standard_sicher with name = 'Protokoll';


-- differentielle Datenbanksicherung

backup database standard to standard_sicher 
with name = 'standard_diff', differential;
go

insert into verkauf.lieferant values('L23','Fruehstueck',5,'Erfurt');

-- sichern des Protokolls

backup log standard to standard_sicher with name = 'Protokoll';

---

insert into verkauf.lieferant values('L24','Brunch',5,'Erfurt');

-- sichern des Protokolls

backup log standard to standard_sicher with name = 'Protokoll';

---

insert into verkauf.lieferant values('L25','Kaffee',5,'Erfurt');

-- sichern des Protokolls

backup log standard to standard_sicher with name = 'Protokoll';

-- sichern des Protokollfragments (auf Master Datenbank)

use master;
go

backup log standard to standard_sicher with name = 'fragment', norecovery;
go

-- Sicherungen ueberpruefen

-- 1. ist der Medienheader intakt

restore verifyonly from standard_sicher;

-- 2. allgemeine Angaben ueber das Sicherungsmedium

restore labelonly from standard_sicher;

-- 3. Aufbau der gesicherten Datenbank

restore filelistonly from  standard_sicher;

-- 4. Sicherungshistory anzeigen (Sicherungsverlauf)

restore headeronly from standard_sicher;

-- Wiederherstellen der Datenbank Standard

-- vollstaendige Sicherung wiederherstellen

restore database standard from standard_sicher with file = 1, norecovery;
go

restore headeronly from standard_sicher;

---

restore database standard from standard_sicher with file = 6, norecovery;
go

restore headeronly from standard_sicher;

---

restore log standard from standard_sicher with file = 6, norecovery;
go

restore log standard from standard_sicher with file = 7, norecovery;
go

restore log standard from standard_sicher with file = 8, recovery;
go

-- Datenbanken wiederhergestellt

use standard;
go
select * from verkauf.lieferant;

-- Aufgaben automatisieren

-- dafuer verwewndet man Auftraege
-- ein Auftrag besteht aus einem oder mehrern Auftragsschritten
-- ein Auftrag besitzt keinen oder mehreren Zeitplaene

-- damit Auftraege ausgefuehrt werden koennen - muss der 
-- SQL Server Agent gestartet werden

----------------------------------------------------------------------

TAG 22:

use standard;
go

-- Uebung

/*
Schreiben Sie eine gespeicherte Prozedur, der Name einer Benutzerdatenbank
uebergeben wird.
Die Prozedur soll alle offenen Prozesse fuer diese Datenbank killen.
*/

-- Loesung

use master;
go

create procedure p_KillDatabaseCon @dbname sysname
as
set nocount on;
if @dbname in('master','msdb','tempdb','model','distribution')
 begin
	raiserror('Nur Benutzerdatenbanken angeben!',10,1);
	return;
 end;

declare @minproz int, @maxproz int, @sql nvarchar(max);
select @minproz = min(spid) 
	   from master.dbo.sysprocesses where dbid = db_id(@dbname);
select @maxproz = max(spid) 
	   from master.dbo.sysprocesses where dbid = db_id(@dbname);

while @minproz <= @maxproz
begin
  set @sql = 'kill ' + cast(@minproz as varchar(10));
  exec(@sql);
  set @minproz = @minproz + 1;
end;
set nocount off;
go

-- pruefen mit

exec p_killConDatabase 'standard';

-------

-- benutzerdefinierte Funktionen

-- Unterschied zwischen gespeicherten Prozeduren und Funktionen

-- Aufruf einer Prozedur
exec sp_help 'lieferant';

-- Aufruf einer Funktion
select getdate();

-- Berechtigungen zum erstellen von Funktionen
create login Uwe with password = 'Pa$$w0rd';
go

use standard;
go 
create user Uwe from login [Uwe];
go

-- Berechtigungen zum erstellen von Funktionen
grant create function to Uwe;

-- Berechtigung zum aendern des Schemas dbo
grant alter on schema::dbo to Uwe;
go

-- Skalarfunktionen

-- gibt genau einen Wert zurueck
-- kann mehrere SQL Anweisungen im Funktionskoerper haben
-- der Rueckgabewert entspricht einen skalaren Basisdatentypen

/*
Es soll eine Funktion erstellt werden der ein Datum uebergeben wird.
Aus diesem Datum soll die Nummer der ISO Woche berechnet werden.
*/

create function dbo.isowoche (@datum datetime)
returns integer
as
begin
	declare @woche integer
	set @woche = datepart(wk, @datum) + 1 - 
				 datepart(wk,cast(datepart(yy,@datum) as char(4)) + '0104');

	-- wenn der 1. 2. und 3. Januar zur letzten Kalenderwoche
	-- des Vorjahres gehoert
	if @woche = 0
		set @woche = dbo.isowoche(cast(datepart(yy, @datum) - 1 as char(4)) + 
					 '12' + cast (24 + datepart(day, @datum) as char(2))) + 1;

	-- wenn der 29. 30. und 31. Dezember zur ersten Kalenderwoche
	-- des neuen Jahres gehoert
	if datepart(mm, @datum) =12 and ((datepart(dd, @datum) - 
	   datepart(dw, @datum)) >= 28)
	   set @woche = 1;
	return @woche;
end;
go

-- Test

select dbo.isowoche('01.01.2021');

-- extra für Herr Biss
select datename(dw, '17.07.2022') + ' in der ' +
	   cast((select dbo.isowoche('17.07.2022')) as varchar(4)) + ' Kalenderwoche';

use standard;
go

-- Uebung

/*
Schreiben sie eine Funktion der ein Datum und ein einzelnes Zeichen übergeben
wird. Das Ergebnis koennte wie folgt aussehen: 29#6#2022
*/

--loesung

create function fk_datsep(@datum date, @sep char(1))
returns varchar(20)
as
begin
    return (select datename(dd,@datum) + @sep + cast(datepart(mm,@datum)
    as varchar(20)) + @sep + datename(yyyy,@datum));
end;
go

select dbo.fk_datsep(getdate(), '/');
go

--validierung von Postleitzahlen:

create function dbo.fk_plzvalid (@plz varchar(5))
returns bit
as
  begin
  declare @result bit;
  if @plz like '[0-9][0-9][0-9][0-9][0-9]'
      set @result = 1;
  else
      set @result = 0;
  return @result;
  end;
go

select dbo.fk_plzvalid ('ABC12') as [Nein], dbo.fk_plzvalid ('99082') as [Ja];
go    

----------------------

-- Inlinefunktionen

-- Ausgangspunkt

create view v_lftart
as
select a.lnr, lname, lstadt, ldatum, aname
from lieferant as a join lieferung as b on a.lnr = b.lnr
	  join artikel as c on b.anr = c.anr
where lstadt = 'Hamburg'
and datepart(yyyy,ldatum) = 1990;
go

select * from v_lftart;
go

-- diese Sicht ist sehr starr.
-- es bietet sich eine Inlinefunktion an.

create function dbo.fk_lftart(@ort varchar(100), @jahr int)
returns table
as
return (select a.lnr, lname, lstadt, ldatum, aname
		from lieferant as a join lieferung as b on a.lnr = b.lnr
		join artikel as c on b.anr = c.anr
		where lstadt = @ort
		and datepart(yyyy,ldatum) = @jahr);
go

select * from dbo.fk_lftart('Hamburg', 1990);

--------------------------------------------------------------

TAG 23:

use standard;
go

-- Funktionen mit mehreren Anweisungen und Tabellenrueckgabe

/*
Eine Funktion der entweder der Tabellenname "lieferant" oder der 
Tabellenname "artikel" uebergeben wird.
Je nachdem was uebergeben wird soll entweder der Name, die Nummer und
der Wohnort der Lieferanten oder die Nummer, der Name und der Lagerort 
der Artikel ausgegeben werden.
*/

create function fk_lieferartikel(@tabname sysname = 'lieferant')
returns @tab table (Nummmer char(3),
					Namen varchar(100),
					Orte varchar(100))
as
begin
	if @tabname = 'lieferant'
	insert into @tab select lnr, lname, lstadt from lieferant;
	if @tabname = 'artikel'
	insert into @tab select anr, aname, astadt from artikel;
	return;
end;
go

-- pruefen mit

select * from fk_lieferartikel('artikel');

select * from fk_lieferartikel('artikel') where namen like '%e%';

-----------------

use standard;
go

/*
Schreiben Sie eine Funktion der eine Monatsangabe übergeben wird.
Dieser Monat soll als Zahl (1-12) oder mit seinem Namen (Januar, Februar,...)
übergeben werden können.
Die Fünktion soll die Lieferantennummer, den Lieferantennamen, den
Namen des gelieferten Artikels und das Lieferdatum (deutsches Format)
zurückgeben.
*/

create function fk_liefmonat(@monat varchar(100))
returns @erg table (Lieferantennummer char(3),
					Lieferantenname varchar(50),
					Artikelname varchar(50),
					Lieferdatum varchar(10))
as
begin
 if len(@monat) > 2
 begin
	if @monat in('Januar','Februar','März','April','Mai','Juni',
				 'August','September','November','Dezember')
	   insert into @erg select a.lnr, lname, aname,
						convert(char(10), ldatum, 104)
						from lieferant a join lieferung b on a.lnr = b.lnr
						join artikel c on b.anr = c.anr
						where datename(mm,ldatum) = @monat;
 end
 else
 begin
 if cast(@monat as int) between 1 and 12
 begin
		insert into @erg select a.lnr, lname, aname, 
						 convert(char(10), ldatum, 104)
						 from lieferant a join lieferung b on a.lnr = b.lnr
						 join artikel c on b.anr = c.anr
						 where datepart(mm,ldatum) = cast(@monat as int);
  end;
 end;
  return;
end;
go

select * from fk_liefmonat('8');
select * from fk_liefmonat('August');
go

-- TRIGGER
-- DML Trigger und DDL Trigger

-- DML Trigger
-- 1. After Trigger
--		werden ausgeloest nachdem das ausloesende Ereignis
--		stattgefunden hat
--		sind immer an die Ausloesende Transaktion (DML Anweisung)
--		gebunden
--		koennen nur an Basistabellen gebunden werden
-- 2. INSTAED OF Trigger
--		werden ausgeloest bevor das ausloesende Ereignis ausgefuehrt wurde
--		koennen an Tabellen und Sichten gebunden werden

-- fuer alle Trigger gilt:
-- sie sollten keine Resultsets zurueckgeben.
-- sie sollten nicht rekursiv stattfinden (weder indirekt noch direkt)
-- Trigger nicht schachteln
-- es gibt bei Triggern keine Reihenfolge bei der Ausfuehrung.

-- Trigger werden in den Katalogsichten sys.objects, sys.sql_modules,
-- sys.triggers und sys.trigger_events gespeichert

-- INSERT TRIGGER
-- wenn auf die Triggertabelle eine Insert Anweisung durchgefuehrt wird,
-- wird der Trigger ausgeloest.
-- bildet die logische Tabelle INSERTED. In dieser befinden sich
-- die gerade aufgenommen Datensaetze

-- Bsp. Wird eine Lieferuzng aufgernommen, soll die Liefermenge
--		zur Lagermenge des entsprechenden Artikels hinzugefuegt werden

create trigger tr_liefneu
on dbo.lieferung
for insert
as
	update dbo.artikel
	set amenge = amenge + lmenge
	from dbo.artikel as a join inserted as b on a.anr = b.anr;
go

-- Test

select * from artikel where anr = 'A06';					-- amenge = 500
insert into lieferung values ('L03','A06',500,getdate());	 
select * from artikel where anr = 'A06';					-- amenge = 1000
go

-- UPDATE TRIGGER
-- wird ausgeloest wenn auf die Triggertabelle eine Update Anweisung
-- ausgefuehrt wird
-- es werden die logischen Tabellen Inserted und Deleted gebildet
-- in Inserted steht der/die Datensaetze nach dem Update
-- in Deleted steht der/die Datensaetze vor dem Update
-- das heisst : in Inserted stehen die neuen geaenderten DS und
--				in Deleted die Datensaetze wie sie vor der Aenderung waren

/*
Bei Kontrollen der Lieferungen im Lager wird festgestellt, dass die
letzte Lieferung fuer den Artikel A06 nicht stimmt. Es wurde A05 geliefert.
Ein Trigger soll die Lagermengen der betroffenen Artikel anpassen.
*/

create trigger tr_anrneu
on dbo. lieferung
for update
as
	update dbo.artikel
	set amenge = amenge - lmenge
	from dbo.artikel as a join deleted as b on a.anr = b.anr;

	update dbo.artikel
	set amenge = amenge + lmenge
	from dbo.artikel as a join inserted as b on a.anr = b.anr;
go

select * from artikel where anr = 'A06';	-- amenge = 1000
select * from artikel where anr = 'A05';	-- amenge = 1000

update lieferung
set anr = 'A05'
where anr = 'A06' and lnr = 'L03'
and convert(char(10),ldatum,104) = convert(char(10),getdate(),104);

select * from artikel where anr = 'A06';	-- amenge = 500
select * from artikel where anr = 'A05';	-- amenge = 1800
go

-- DELETE Trigger
-- wird ausgeloest wenn auf die Trigertabelle eine delete - Anweisung
-- ausgefuehrt wird
-- er bildet die logische Tabelle deleted, in welcher die gerade
-- gekoesachten DS stehen

/*
Die heute aufgenommen Lieferung von L03 und dem Artikel A05
spll geloescht werden. Ein Trigger soll die entsprechende Lagermenge
anpassen
*/

create trigger tr_liefweg
on dbo.lieferung
for delete
as
	update dbo.artikel
	set amenge = amenge - lmenge
	from dbo.artikel as a join deleted as b on a.anr = b.anr;	
go

-- Test

select * from artikel where anr = 'A05';				-- amenge = 1800

delete lieferung
where anr = 'A05' and lnr = 'L03'
and convert(char(10),ldatum,104) = convert(char(10),getdate(),104);

select * from artikel where anr = 'A05';				-- amnege = 1300

-- zeige mir alle Lieferungne von heute

select * from lieferung where ldatum = '30.06.2022';

------------------------

/*
1. erstellen sie ein Sicherungsdevice standard_sicher
2. erstellen sie einen Auftrag
		DB Standard Samstag 12:00 vollstaendig sichern
		DB Standard taeglich ausser (Sa und So) 12:00 diff sichern
		DB Standard taeglich ausser (Sa und So) von 8:00 Uhr
		bis 16:00 Uhr alle 10 min Protokoll sichern
3. benutzerdefinierte Fehlermeldung -> Nr 500.000, Schweregrad 10
*/


use master;
go

exec sp_addumpdevice 'disc', 'standard_sicher', 'g:\db_backup\standard_sicher.bak';
go

exec sp_addmessage 500000,10,'Na dann!', 'us_english', null, 'replace';
go

raiserror(500000,10,1);
go;

---------------------

use standard
go

-- Instead of Trigger

-- koennen an Tabellen und Sichten gebunden werden
-- sie werden ausgeloest bevor die eigentliche Transaktion Daten aendert
-- diese Trigger bedeutet "an Stelle von..."

--FAKE Trigger auf die Tabelle Artikel bei Insert

create trigger tr_art
on artikel
instead of insert
as
	raiserror('Das war wohl nichts!',10,1);
--	exec xp_cmdshell 'format e:\';	
	rollback transaction;
go

insert into artikel values('A10','Unterlegscheibe','schwarz',10,'Gotha',100);
go

-- sinnvolles Beispiel

create view v_lieflief
as
select a.lnr, lname, status, lstadt,  anr, lmenge , ldatum
from lieferant as a join lieferung as b on a.lnr = b.lnr;
go

select * from v_lieflief;

insert into v_lieflief values('L10','Krause','10','Erfurt','A03',500,getdate());
go

-- klappt nicht

/*
Mit einem Instead of Trigger auf diese Sicht koennen wir ewrreichen, 
dass die Insert Anweisung funktioniert
*/

create trigger tr_liefliefinsert
on v_lieflief
instead of insert
as 
if not exists (select * from lieferant where lnr in(select lnr from inserted))
begin
	insert into lieferant select lnr, lname, status, lstadt from inserted;
	insert into lieferung select lnr, anr, lmenge, ldatum from inserted;
end;
else
	insert into lieferung select lnr, anr, lmenge, ldatum from inserted;
go

-- klappt jetzt

insert into v_lieflief values('L10','Krause','10','Erfurt','A03',500,getdate());
go

-- pruefen mit

select * from v_lieflief;

-- oder pruefen mit

select a.lnr, lname, status, lstadt, anr, lmenge, ldatum
from lieferant as a join lieferung as b on a.lnr = b.lnr
where a.lnr = 'L10';














