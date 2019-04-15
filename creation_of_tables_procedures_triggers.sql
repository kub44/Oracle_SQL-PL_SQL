
CREATE TABLE pr_faktura_naglowek (
    nr_faktury        NUMBER(8) NOT NULL,
    nr_klienta        NUMBER(8) NOT NULL,
    data_faktury      DATE NOT NULL,
    wartosc_faktury   NUMBER DEFAULT 0,
    kod_wojewodztwa   NUMBER(2) NULL,
    status            VARCHAR2(20) DEFAULT 'OTWARTA'
)
    LOGGING;

ALTER TABLE pr_faktura_naglowek
    ADD CHECK (
        status IN (
            'OTWARTA','ZAMKNIETA'
        )
    );

ALTER TABLE pr_faktura_naglowek ADD CONSTRAINT faktura_naglowek_pk PRIMARY KEY ( nr_faktury );

CREATE TABLE pr_faktura_pozycja (
    nr_faktury       NUMBER(8) NOT NULL,
    nr_pozycji       NUMBER(8) NOT NULL,
    kod_leku         NUMBER(8) NOT NULL,
    cena_zakupu      NUMBER NOT NULL,
    ilosc            NUMBER NOT NULL,
    stawka_podatku   NUMBER(2),
    recepta          VARCHAR2(3)
)
    LOGGING;

ALTER TABLE pr_faktura_pozycja ADD CONSTRAINT faktura_pozycja_pk PRIMARY KEY ( nr_faktury,nr_pozycji );

CREATE TABLE pr_klient (
    nr_klienta        NUMBER(8) NOT NULL,
    imie              VARCHAR2(25) NOT NULL,
    nazwisko          VARCHAR2(40) NOT NULL,
    "e-mail"          VARCHAR2(60) NOT NULL,
    telefon           NUMBER(9),
    ulica             VARCHAR2(45) NOT NULL,
    miasto            VARCHAR2(25) NOT NULL,
    kod_pocztowy      VARCHAR2(6) NOT NULL,
    kod_wojewodztwa   NUMBER(2) NOT NULL
)
    LOGGING;

ALTER TABLE pr_klient ADD CONSTRAINT klient_pk PRIMARY KEY ( nr_klienta );

CREATE TABLE pr_lek (
    kod_leku         NUMBER(8) NOT NULL,
    pr_typ_leku         VARCHAR2(20) NOT NULL,
    nazwa_leku       VARCHAR2(100) NOT NULL,
    cena_zakupu      NUMBER NOT NULL,
    cena_sprzedazy   NUMBER NOT NULL,
    stawka_podatku   NUMBER(2) NOT NULL,
    recepta          VARCHAR2(3) NOT NULL,
    ilosc            NUMBER(10) NOT NULL
)
    LOGGING;

ALTER TABLE pr_lek
    ADD CHECK (
        recepta IN (
            'NIE','TAK'
        )
    );

ALTER TABLE pr_lek ADD CONSTRAINT lek_pk PRIMARY KEY ( kod_leku );

CREATE TABLE pr_typ_leku (
    pr_typ_leku      VARCHAR2(20) NOT NULL,
    nazwa_pelna   VARCHAR2(100) NOT NULL,
    rabat         NUMBER(3)
)
    LOGGING;

ALTER TABLE pr_typ_leku ADD CONSTRAINT typ_leku_pk PRIMARY KEY ( pr_typ_leku );

CREATE TABLE pr_wojewodztwa (
    kod_wojewodztwa     NUMBER(2) NOT NULL,
    nazwa_wojewodztwa   VARCHAR2(40) NOT NULL
)
    LOGGING;

ALTER TABLE pr_wojewodztwa ADD CONSTRAINT wojewodztwa_pk PRIMARY KEY ( kod_wojewodztwa );

ALTER TABLE pr_faktura_pozycja
    ADD CONSTRAINT faktura_naglowek_fk FOREIGN KEY ( nr_faktury )
        REFERENCES pr_faktura_naglowek ( nr_faktury )
    NOT DEFERRABLE;

ALTER TABLE pr_faktura_naglowek
    ADD CONSTRAINT klient_fk FOREIGN KEY ( nr_klienta )
        REFERENCES pr_klient ( nr_klienta )
    NOT DEFERRABLE;

ALTER TABLE pr_faktura_pozycja
    ADD CONSTRAINT lek_fk FOREIGN KEY ( kod_leku )
        REFERENCES pr_lek ( kod_leku )
    NOT DEFERRABLE;

ALTER TABLE pr_lek
    ADD CONSTRAINT typ_leku_fk FOREIGN KEY ( pr_typ_leku )
        REFERENCES pr_typ_leku ( pr_typ_leku )
    NOT DEFERRABLE;

ALTER TABLE pr_faktura_naglowek
    ADD CONSTRAINT wojewodztwa_fk FOREIGN KEY ( kod_wojewodztwa )
        REFERENCES pr_wojewodztwa ( kod_wojewodztwa )
    NOT DEFERRABLE;

ALTER TABLE pr_klient
    ADD CONSTRAINT wojewodztwa_fkv1 FOREIGN KEY ( kod_wojewodztwa )
        REFERENCES pr_wojewodztwa ( kod_wojewodztwa )
    NOT DEFERRABLE;


/
CREATE SEQUENCE  SEQ_PR_NAGLOWEK  MINVALUE 1 MAXVALUE 9999999999999 INCREMENT BY 1 START WITH 1 CACHE 20;
/


CREATE SEQUENCE  SEQ_PR_LEK  MINVALUE 1 MAXVALUE 99999999999 INCREMENT BY 1 START WITH 1 CACHE 20;
/

CREATE SEQUENCE  SEQ_PR_KLIENT MINVALUE 1 MAXVALUE 99999999999999 INCREMENT BY 1 START WITH 1 CACHE 20;
	
/
create or replace FUNCTION FN_PR_DAJ_KOD_LEKU
RETURN NUMBER
AS 
    v_tmp   pr_lek.kod_leku%type;
BEGIN
    select * into v_tmp
    from 
    (
        select kod_leku from pr_lek
        order by dbms_random.value
    )
    where rownum=1;
    
    return v_tmp;

END FN_PR_DAJ_KOD_LEKU;

/

create or replace FUNCTION FN_PR_DAJ_ILOSC_LEKU (v_kod_leku pr_lek.kod_leku%type)
RETURN pr_lek.ilosc%type
AS 
    v_ilosc     pr_lek.ilosc%type;
    v_return    pr_lek.ilosc%type;
    
BEGIN
    select ilosc into v_ilosc
    from pr_lek
    where kod_leku=v_kod_leku;
    
    v_ilosc := round(v_ilosc/3);
    
    if v_ilosc = 0
        then return 0;
    else
    select round(dbms_random.value(1, v_ilosc)) into v_return
    from dual;
    end if;
    
    if v_return > 30
        then v_return := round(v_return/4);
    end if;
    
    return v_return;
    end;

/

create or replace FUNCTION FN_PR_DAJ_NR_KLIENTA
RETURN NUMBER 
AS
    v_tmp   pr_klient.nr_klienta%type;
BEGIN
    select * into v_tmp
    from
      (
        select nr_klienta
        from pr_klient
        order by dbms_random.value
        
      )
      where rownum=1;
      
      return v_tmp;
  
  
END FN_PR_DAJ_NR_KLIENTA;

/
create or replace TRIGGER TR_PR_INSERT_LEK 
BEFORE INSERT ON PR_LEK 
FOR EACH ROW
    BEGIN
    :NEW.kod_leku := SEQ_PR_LEK.Nextval;
  NULL;
END;
/
create or replace TRIGGER "TR_PR_INSERT_KLIENT" 
BEFORE INSERT ON PR_KLIENT 
FOR EACH ROW
    BEGIN
    :NEW.nr_klienta := SEQ_PR_KLIENT.Nextval;
  NULL;
END;
/
create or replace TRIGGER "TR_PR_NAGLOWEK" 
BEFORE INSERT OR UPDATE ON PR_FAKTURA_NAGLOWEK
FOR EACH ROW
declare
    v_tmp               number;
    v_faktury_count     number;
    v_wylosowana        number;
    v_date              date;
    
    v_ile_pozycji       number;
    v_ilosc             pr_lek.ilosc%type;
    v_ile_dodac         pr_lek.ilosc%type;
    counter             integer default 1;
    v_ile_lekow         pr_lek.kod_leku%type;
    v_kod_wojewodztwa      pr_klient.kod_wojewodztwa%type;
    
    v_wartosc_faktury   pr_faktura_naglowek.wartosc_faktury%type;
    v_wartosc_tmp       pr_faktura_naglowek.wartosc_faktury%type;
    v_ilosc_tmp         pr_faktura_pozycja.ilosc%type;
    v_cena_tmp          pr_faktura_pozycja.cena_zakupu%type;
    

BEGIN
    if inserting then
        v_tmp := seq_pr_naglowek.nextval;   --sekwencja
        
        select count(*) into v_faktury_count
        from pr_faktura_naglowek;       --sprawdzam ile jest faktur
    
    if v_faktury_count = 0
    then
        v_date := '18/01/01';   --data pierwszej faktury
        
    else --jesli istnieja juz jakies faktury
        select max(data_faktury) into v_date
        from pr_faktura_naglowek;
        
        if v_date + 5 <= '18/12/31'
        then
        
        v_wylosowana := round(dbms_random.value(0,5)); --data nastepnej faktury
        
        v_date := v_date + v_wylosowana;
        
        else v_date := '18/12/31';
        end if;
    
    end if;
    
    
    :NEW.nr_faktury     := v_tmp;
    :NEW.data_faktury   := v_date;
    
    
    
    elsif updating('status') then
        
            select count(*) into v_ile_lekow
            from pr_lek;            --liczba lekow w bazie
            
            for counter in 1..v_ile_lekow loop
            
                select ilosc into v_ilosc
                from pr_lek
                where kod_leku = counter;
                
                if v_ilosc < 4 then
                    v_ile_dodac := round(dbms_random.value(1,30));
                else
                    v_ile_dodac := 0;
                    
                end if;
                
                update pr_lek
                set ilosc = ilosc + v_ile_dodac
                where kod_leku = counter;
                
            end loop;
                    
    select count(*) into v_ile_pozycji
    from pr_faktura_pozycja
    where nr_faktury = :OLD.nr_faktury;
    
    v_wartosc_faktury := 0;
    
    for counter in 1 .. v_ile_pozycji loop
    
        select ilosc into v_ilosc_tmp
        from pr_faktura_pozycja
        where nr_pozycji=counter and nr_faktury = :OLD.nr_faktury;
        
        select cena_zakupu into v_cena_tmp
        from pr_faktura_pozycja
        where nr_pozycji = counter and nr_faktury = :OLD.nr_faktury;
    
        v_wartosc_tmp := v_ilosc_tmp * v_cena_tmp;
        v_wartosc_faktury := v_wartosc_faktury+v_wartosc_tmp;
        v_wartosc_tmp := 0;
    end loop;
    
    :NEW.wartosc_faktury := v_wartosc_faktury;
    
    end if;
        
     select kod_wojewodztwa into    v_kod_wojewodztwa
     from pr_klient
     where nr_klienta = :NEW.nr_klienta;
     
     :NEW.kod_wojewodztwa := v_kod_wojewodztwa;
    
        
        
    
END;
/
create or replace TRIGGER TR_PR_POZYCJA 
BEFORE DELETE OR INSERT OR UPDATE ON PR_FAKTURA_POZYCJA 
for each row
declare
    v_if_enough                     number;
    v_if_exists                     number;
    v_ile_wszystkich                number;
    
    v_cena_leku                     pr_lek.cena_sprzedazy%type;
    v_kod_leku                      pr_lek.kod_leku%type;
    v_stawka_podatku                pr_lek.stawka_podatku%type;
    v_recepta                       pr_lek.recepta%type;
    v_ile_wszystkich_tmp            number;
    
BEGIN
  if inserting
  then
        select ilosc into v_if_enough
        from pr_lek
        where kod_leku = :NEW.kod_leku;
        
        if v_if_enough >= :NEW.ilosc then
            
            select count(*) into v_if_exists
            from Pr_Faktura_Pozycja     --sprawdzam czy juz taki istnieje
                                        --o danym kodzie 
            where kod_leku = :NEW.kod_leku and nr_faktury = :NEW.nr_faktury;
            
            if v_if_exists = 0 then     --jesli nie ma takiej pozycji 
            
                select count(*) into v_ile_wszystkich_tmp
                from pr_faktura_pozycja
                where nr_faktury = :NEW.nr_faktury;
                
                if v_ile_wszystkich_tmp = 0 then    --jesli nie ma zadnej pozycji
                    v_ile_wszystkich := 0;
                else 
                    select max(nr_pozycji) into v_ile_wszystkich
                    from pr_faktura_pozycja
                    where nr_faktury = :NEW.nr_faktury;
                end if;
                
                v_ile_wszystkich := v_ile_wszystkich+1;
                
                select cena_sprzedazy into v_cena_leku
                from pr_lek
                where kod_leku = :NEW.kod_leku;
                
                select stawka_podatku into v_stawka_podatku
                from pr_lek
                where kod_leku = :NEW.kod_leku;
                
                select recepta into v_recepta
                from pr_lek
                where kod_leku = :NEW.kod_leku;
                
                :NEW.nr_pozycji         := v_ile_wszystkich;
                :NEW.cena_zakupu        := v_cena_leku;
                :NEW.stawka_podatku     := v_stawka_podatku;
                :NEW.recepta            := v_recepta;
                
            elsif v_if_exists <> 0 
            then raise_application_error(-20005,
                    'Lek o kodzie '|| :NEW.kod_leku ||' juz istnieje!!');
            end if;
            
            
            update pr_lek
            set ilosc = ilosc - :NEW.ilosc
            where kod_leku = :NEW.kod_leku;
        
        elsif v_if_enough < :NEW.ilosc 
            then raise_application_error(-20005,  'Nie wystarczajaca ilosc w magazynie leku o kodzie '|| :NEW.kod_leku||'');
            
        end if;
        
        end if;
            
        
        
  
                   
END;
/

create or replace PROCEDURE PR_PR_GENERUJ AS 
    v_nr_faktury        pr_faktura_naglowek.nr_faktury%type;
    v_nr_klienta        pr_klient.nr_klienta%type;
    v_data_faktury      pr_faktura_naglowek.data_faktury%type;
    v_kod_wojewodztwa   pr_faktura_naglowek.kod_wojewodztwa%type;
    
    --pozycja
    v_kod_leku          pr_lek.kod_leku%type;
    v_ilosc             pr_lek.ilosc%type;
    
    
    v_losowa_ilosc_leku pr_lek.ilosc%type;
    v_czy_juz_istnieje  number;
    
    v_koniec_petli     number;
    v_data_petli    date;
    
    v_stop              boolean;
    v_ile_lekow         pr_lek.kod_leku%type;
    v_counter           number;
    
    
BEGIN

    v_stop := false;
    
    while v_stop <> true loop   
    
    select count(*) into v_koniec_petli
    from pr_faktura_naglowek;
    
    if v_koniec_petli = 0
    then v_data_petli := '18/01/01';
    
    else
        select max(data_faktury) into v_data_petli
        from pr_faktura_naglowek;
    end if;
    
    
    if v_data_petli + 5 <= '18/12/31'
    then
        v_nr_klienta := fn_pr_daj_nr_klienta();
        
        insert into pr_faktura_naglowek(nr_klienta)
        values  (
                        v_nr_klienta
                );
        select nr_faktury into v_nr_faktury
        from pr_faktura_naglowek
        where status='OTWARTA';
        
        select data_faktury into v_data_faktury
        from pr_faktura_naglowek
        where nr_faktury = v_nr_faktury;
        
        --ile pozycji na fakturze
        
        select count(*) into v_ile_lekow
        from pr_lek;
        
        v_ile_lekow := round(dbms_random.value(1, v_ile_lekow));
        
        --
        v_counter :=0;
        while v_counter <> v_ile_lekow loop
        
        v_kod_leku := fn_pr_daj_kod_leku();
        
        select count(*) into v_czy_juz_istnieje
        from pr_faktura_pozycja
        where kod_leku = v_kod_leku and nr_faktury = v_nr_faktury;
        
        if v_czy_juz_istnieje = 0
        then
            v_ilosc := fn_pr_daj_ilosc_leku(v_kod_leku);
            
            if v_ilosc > 0
            then
                insert into pr_faktura_pozycja(nr_faktury, kod_leku, ilosc)
                    values  (
                                v_nr_faktury, v_kod_leku, v_ilosc
                            );
            v_counter := v_counter+1;
            
            end if;
            end if;
            
            end loop;
            
            
            update pr_faktura_naglowek
            set status = 'ZAMKNIETA'
            where nr_faktury = v_nr_faktury;
            
            
            elsif v_data_petli + 5 > '18/12/31'
            then
                v_stop := true;
            end if;
            
            end loop;
            
   
  NULL;
END PR_PR_GENERUJ;
/

create or replace view PR_NAJLEPSZY_LEK
as

 select kod,typ,nazwa,czy_recepta,Cena,Suma,to_char(Suma*c.cena_sprzedazy,'999999.99') as Sprzedaz 
from
(
select a.kod_leku as kod, d.nazwa_pelna as typ, b.nazwa_leku as nazwa, b.recepta as czy_recepta, a.cena_zakupu as Cena,  sum(a.ilosc) as Suma
from pr_faktura_pozycja a, pr_lek b, pr_typ_leku d
where a.kod_leku=b.kod_leku and d.pr_typ_leku=b.pr_typ_leku
group by a.kod_leku, d.nazwa_pelna, b.nazwa_leku, a.cena_zakupu, b.recepta
order by Suma desc
)
,pr_lek c
where c.kod_leku=kod
order by Sprzedaz desc;
/
create or replace view PR_KLIENCI_WYDATKI
AS
select k.nr_klienta, k.imie, k.nazwisko, k.ulica,k.kod_pocztowy, k.miasto, w.nazwa_wojewodztwa,
        sum(wartosc_faktury) as "Suma"
from pr_klient k , pr_faktura_naglowek f, pr_wojewodztwa w
where k.nr_klienta=f.nr_klienta
and w.kod_wojewodztwa=k.kod_wojewodztwa
group by k.nr_klienta, k.imie, k.nazwisko, k.ulica, k.miasto, w.nazwa_wojewodztwa,
k.kod_pocztowy
order by nr_klienta;
/
create or replace view PR_OBROT_MIESIACE
AS
select to_char(data_faktury, 'YYYY/MM') Okres, to_char(to_date(extract(month from(data_faktury)), 'MM'), 'month') Miesiac, sum(wartosc_faktury) Suma
from pr_faktura_naglowek
group by extract(month from(data_faktury)), to_char(data_faktury, 'YYYY/MM')
order by extract(month from(data_faktury));
/



