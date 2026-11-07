-- Kehitysympäristön siemendata: Kuopio.
-- KAIKKI TARJOAJAT OVAT KUVITTEELLISIA ("Esimerkki"-nimet). Älä aja tuotantokantaan.
-- Kaupunginosien keskipisteet ovat likimääräisiä. Postinumeroille käytetään
-- kaupungin keskipistettä, kunnes ne korvataan Postin postinumeroaineistolla.

set search_path = public, extensions;

-- ---------------------------------------------------------------------------
-- Kaupunki ja kaupunginosat
-- ---------------------------------------------------------------------------
insert into public.cities (code, name, center, active)
values ('kuopio', '{"fi": "Kuopio", "sv": "Kuopio", "en": "Kuopio"}',
        st_setsrid(st_makepoint(27.6783, 62.8925), 4326)::geography, true);

insert into public.city_slugs (city_id, locale, slug)
select c.id, l.locale, 'kuopio'
  from public.cities c
  cross join (values ('fi'::public.locale), ('sv'), ('en')) l(locale)
 where c.code = 'kuopio';

insert into public.districts (city_id, code, name, center)
select c.id, d.code, jsonb_build_object('fi', d.name_fi, 'sv', d.name_fi, 'en', d.name_fi),
       st_setsrid(st_makepoint(d.lng, d.lat), 4326)::geography
  from public.cities c
  cross join (values
    ('keskusta',         'Keskusta',         62.8925, 27.6783),
    ('puijonlaakso',     'Puijonlaakso',     62.9050, 27.6500),
    ('niirala',          'Niirala',          62.8830, 27.6930),
    ('neulamaki',        'Neulamäki',        62.8740, 27.6350),
    ('jynkka',           'Jynkkä',           62.8530, 27.6650),
    ('saaristokaupunki', 'Saaristokaupunki', 62.8550, 27.6400),
    ('petonen',          'Petonen',          62.8380, 27.6130)
  ) d(code, name_fi, lat, lng)
 where c.code = 'kuopio';

insert into public.district_slugs (district_id, locale, city_id, slug)
select d.id, l.locale, d.city_id, d.code
  from public.districts d
  cross join (values ('fi'::public.locale), ('sv'), ('en')) l(locale);

insert into public.postal_codes (code, city_id, center)
select pc.code, c.id, c.center
  from public.cities c
  cross join (values ('70100'), ('70110'), ('70150'), ('70200'), ('70300'), ('70340'),
                     ('70420'), ('70460'), ('70500'), ('70600'), ('70620'), ('70780'),
                     ('70800'), ('70820'), ('70870'), ('70900')) pc(code)
 where c.code = 'kuopio';

-- ---------------------------------------------------------------------------
-- Palvelut
-- ---------------------------------------------------------------------------
insert into public.services (code, name, description, default_duration_min, sort_order) values
  ('tire_change',
   '{"fi": "Renkaanvaihto", "sv": "Däckbyte", "en": "Tyre change"}',
   '{"fi": "Kesä- ja talvirenkaiden vaihto vanteineen, kiristys momenttiavaimella.", "sv": "Byte av sommar- och vinterdäck på fälg, åtdragning med momentnyckel.", "en": "Swap of mounted summer and winter tyres, tightened with a torque wrench."}',
   30, 10),
  ('tire_change_balancing',
   '{"fi": "Renkaanvaihto ja tasapainotus", "sv": "Däckbyte och balansering", "en": "Tyre change and balancing"}',
   '{"fi": "Renkaanvaihto ja pyörien tasapainotus.", "sv": "Däckbyte och balansering av hjulen.", "en": "Tyre change and wheel balancing."}',
   60, 20);

-- ---------------------------------------------------------------------------
-- Tarjoajat (kuvitteellisia)
-- ---------------------------------------------------------------------------
with src (slug, kind, status, display_name, district, radius_km, desc_fi) as (
  values
    ('esimerkki-rengaspiste-keskusta',  'company',    'active',  'Esimerkki Rengaspiste Keskusta',  'keskusta',         null, 'Kahden nostimen rengasliike keskustassa.'),
    ('esimerkki-rengastalo-petonen',    'company',    'active',  'Esimerkki Rengastalo Petonen',    'petonen',          null, 'Rengasliike Petosella, myös tasapainotus.'),
    ('esimerkki-autohuolto-jynkka',     'company',    'active',  'Esimerkki Autohuolto Jynkkä',     'jynkka',           null, 'Pieni autohuolto Jynkässä.'),
    ('esimerkki-rengas-neulamaki',      'company',    'active',  'Esimerkki Rengas Neulamäki',      'neulamaki',        null, 'Rengastyöt Neulamäessä.'),
    ('esimerkki-rengasverstas-saaristo','company',    'active',  'Esimerkki Rengasverstas Saaristo','saaristokaupunki', 8.0,  'Verstas ja kotipihapalvelu Saaristokaupungissa.'),
    ('esimerkki-pikarengas-niirala',    'company',    'active',  'Esimerkki Pikarengas Niirala',    'niirala',          null, 'Nopeat vaihdot Niiralassa.'),
    ('esimerkki-rengasasema-puijo',     'company',    'active',  'Esimerkki Rengasasema Puijo',     'puijonlaakso',     null, 'Rengasasema Puijonlaaksossa.'),
    ('esimerkki-autokorjaamo-petonen',  'company',    'active',  'Esimerkki Autokorjaamo Petonen',  'petonen',          null, 'Korjaamo Petosella.'),
    ('esimerkki-rengasmestari',         'company',    'active',  'Esimerkki Rengasmestari',         'keskusta',         null, 'Rengasmestari keskustan laidalla.'),
    ('esimerkki-mobiilirengas',         'company',    'active',  'Esimerkki Mobiilirengas Oy',      'jynkka',           15.0, 'Kaksi pakettiautoa, vaihto kotipihalla koko Kuopiossa.'),
    ('esimerkki-matti',                 'individual', 'active',  'Matti E.',                        'petonen',          6.0,  'Iltaisin ja viikonloppuisin kotipihalla.'),
    ('esimerkki-liisa',                 'individual', 'active',  'Liisa E.',                        'saaristokaupunki', 5.0,  'Autoalan opiskelija, omat välineet.'),
    ('esimerkki-jussi',                 'individual', 'active',  'Jussi E.',                        'neulamaki',        7.0,  'Vaihdot kotipihalla Neulamäen ympäristössä.'),
    ('esimerkki-aino',                  'individual', 'active',  'Aino E.',                         'puijonlaakso',     5.0,  'Viikonloppuisin.'),
    ('esimerkki-pekka',                 'individual', 'pending', 'Pekka E.',                        'petonen',          5.0,  'Odottaa hyväksyntää.')
)
insert into public.providers (slug, kind, status, display_name, description, city_id, district_id,
                              location, service_radius_km, published_at)
select s.slug, s.kind::public.provider_kind, s.status::public.provider_status, s.display_name,
       jsonb_build_object('fi', s.desc_fi),
       d.city_id, d.id,
       -- Hajautetaan sijainnit hieman kaupunginosan keskipisteen ympärille.
       st_project(d.center, 300 + (abs(hashtext(s.slug)) % 900), radians(abs(hashtext(s.slug || 'b')) % 360))::geography,
       s.radius_km,
       case when s.status = 'active' then now() end
  from src s
  join public.districts d on d.code = s.district;

-- Resurssit: korjaamoilla nostimet, liikkuvilla pakettiautot.
insert into public.provider_resources (provider_id, name, location_type)
select p.id, r.name, r.location_type::public.location_type
  from public.providers p
  join (values
    ('esimerkki-rengaspiste-keskusta',   'Nostin 1',       'workshop'),
    ('esimerkki-rengaspiste-keskusta',   'Nostin 2',       'workshop'),
    ('esimerkki-rengastalo-petonen',     'Nostin 1',       'workshop'),
    ('esimerkki-rengastalo-petonen',     'Nostin 2',       'workshop'),
    ('esimerkki-autohuolto-jynkka',      'Nostin',         'workshop'),
    ('esimerkki-rengas-neulamaki',       'Nostin',         'workshop'),
    ('esimerkki-rengasverstas-saaristo', 'Nostin 1',       'workshop'),
    ('esimerkki-rengasverstas-saaristo', 'Nostin 2',       'workshop'),
    ('esimerkki-rengasverstas-saaristo', 'Huoltoauto',     'mobile'),
    ('esimerkki-pikarengas-niirala',     'Nostin',         'workshop'),
    ('esimerkki-rengasasema-puijo',      'Nostin',         'workshop'),
    ('esimerkki-autokorjaamo-petonen',   'Nostin',         'workshop'),
    ('esimerkki-rengasmestari',          'Nostin',         'workshop'),
    ('esimerkki-mobiilirengas',          'Pakettiauto 1',  'mobile'),
    ('esimerkki-mobiilirengas',          'Pakettiauto 2',  'mobile'),
    ('esimerkki-matti',                  'Matti',          'mobile'),
    ('esimerkki-liisa',                  'Liisa',          'mobile'),
    ('esimerkki-jussi',                  'Jussi',          'mobile'),
    ('esimerkki-aino',                   'Aino',           'mobile'),
    ('esimerkki-pekka',                  'Pekka',          'mobile')
  ) r(slug, name, location_type) on r.slug = p.slug;

-- Hinnat: korjaamoilla 39–55 € / 69–89 €, kotipihalla korkeampi hinta ja matkalisä.
insert into public.provider_services (provider_id, service_id, location_type, price_cents,
                                      travel_fee_cents, duration_min)
select p.id, s.id, lt.location_type,
       case
         when s.code = 'tire_change' and lt.location_type = 'workshop'
           then 3900 + (abs(hashtext(p.slug)) % 5) * 400
         when s.code = 'tire_change_balancing' and lt.location_type = 'workshop'
           then 6900 + (abs(hashtext(p.slug)) % 5) * 500
         when p.kind = 'individual'
           then 4500 + (abs(hashtext(p.slug)) % 3) * 500
         else 5900 + (abs(hashtext(p.slug)) % 5) * 500
       end,
       case when lt.location_type = 'mobile' then 500 + (abs(hashtext(p.slug)) % 3) * 500 else 0 end,
       case when s.code = 'tire_change' then (case when lt.location_type = 'mobile' then 45 else 30 end)
            else 60 end
  from public.providers p
  cross join public.services s
  join lateral (
    select distinct r.location_type from public.provider_resources r where r.provider_id = p.id
  ) lt on true
 -- Kotipihalla tasapainotusta ei tarjota (vaatii koneen).
 where not (s.code = 'tire_change_balancing' and lt.location_type = 'mobile');

-- Aukioloajat.
-- Korjaamot: ma–pe 8–17, la 9–14. Liikkuva yritys: ma–la 8–20.
-- Yksityiset: ma–pe 16–21, la–su 10–18.
insert into public.availability_rules (resource_id, weekday, start_time, end_time)
select r.id, w.weekday, w.start_time, w.end_time
  from public.provider_resources r
  join public.providers p on p.id = r.provider_id
  cross join lateral (
    select * from (values
      ('workshop', 1, time '08:00', time '17:00'), ('workshop', 2, '08:00', '17:00'),
      ('workshop', 3, '08:00', '17:00'), ('workshop', 4, '08:00', '17:00'),
      ('workshop', 5, '08:00', '17:00'), ('workshop', 6, '09:00', '14:00'),
      ('company_mobile', 1, '08:00', '20:00'), ('company_mobile', 2, '08:00', '20:00'),
      ('company_mobile', 3, '08:00', '20:00'), ('company_mobile', 4, '08:00', '20:00'),
      ('company_mobile', 5, '08:00', '20:00'), ('company_mobile', 6, '08:00', '20:00'),
      ('individual', 1, '16:00', '21:00'), ('individual', 2, '16:00', '21:00'),
      ('individual', 3, '16:00', '21:00'), ('individual', 4, '16:00', '21:00'),
      ('individual', 5, '16:00', '21:00'), ('individual', 6, '10:00', '18:00'),
      ('individual', 7, '10:00', '18:00')
    ) v(profile, weekday, start_time, end_time)
    where v.profile = case
      when p.kind = 'individual' then 'individual'
      when r.location_type = 'mobile' then 'company_mobile'
      else 'workshop'
    end
  ) w;
