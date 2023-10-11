--1. Em quantas partidas o Palmeiras recebeu cartão amarelo no segundo tempo quando jogava como visitante?
select c.clube, count(distinct c.partida_id) 
from database1.tb_campeonato_brasileiro_cartoes c
join database1.tb_campeonato_brasileiro_full bf on c.partida_id = bf.id
where c.cartao = 'Amarelo'
and c.clube = 'Palmeiras'
and c.minuto >= '46'
and bf.visitante = 'Palmeiras'
group by 1;


--2. Qual foi a média de gols do Cruzeiro nas partidas em que venceu jogando fora de casa?
select avg(cast(visitante_placar as int)) --TODO - cast do dado na ingestao
from database1.tb_campeonato_brasileiro_full 
where visitante = 'Cruzeiro'
and vencedor = 'Cruzeiro'
;

--3. Qual foi o clube que teve mais cartões vermelhos quando jogava em casa?
select bf.mandante, count(1)
from database1.tb_campeonato_brasileiro_full bf
join database1.tb_campeonato_brasileiro_cartoes c on bf.id = c.partida_id and bf.mandante = c.clube
where c.cartao = 'Vermelho'
group by 1
order by count(1) desc
;


--4. Quantos cartões amarelos o São Paulo levou nas partidas em que ganhou quando jogava fora de casa e fez pelo menos 2 gols no segundo tempo?
with partidas_mais_que_2_gols_seg_tempo_fora_de_casa as (
	select 
		  bf.id as partida_id
		, bf.visitante as clube
		, count(1) as gols_segundo_tempo
	from database1.tb_campeonato_brasileiro_full bf
	join database1.tb_campeonato_brasileiro_gols g on bf.id = g.partida_id and bf.visitante = g.clube 
	where bf.visitante = 'Sao Paulo'
		and bf.vencedor = 'Sao Paulo'
		and cast(bf.visitante_placar as int) >= 2
		and g.minuto >= '46'
	group by 1,2
	having count(1) >= 2
)
select --t.partida_id, 
	count(1)
from partidas_mais_que_2_gols_seg_tempo_fora_de_casa t 
join database1.tb_campeonato_brasileiro_cartoes c on t.partida_id = c.partida_id and c.clube = t.clube
where c.cartao = 'Amarelo'
--group by 1
;
