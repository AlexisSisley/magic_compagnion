// Fichier : lib/data/glossary_data.dart

// Un modèle simple pour nos mots-clés
class Keyword {
  final String term;
  final String definition;

  Keyword({required this.term, required this.definition});
}

// La liste de tous les mots-clés, basée sur votre texte
final List<Keyword> glossaryTerms = [
  Keyword(
    term: "Contact Mortel",
    definition: "Une capacité mot-clé trouvée sur des créatures. Une créature qui subit n'importe quel nombre de blessures d'une créature qui a le contact mortel est détruite. Le contact mortel n'a aucun effet sur les joueurs ou les planeswalkers."
  ),
  Keyword(
    term: "Double Initiative",
    definition: "Une capacité mot-clé trouvée sur des créatures. Les créatures avec la double initiative infligent leurs blessures de combat deux fois. Quand vous parvenez à l’étape d’attribution des blessures de combat, vérifiez si une ou plusieurs créatures, attaquantes ou bloqueuses, ont l’initiative ou la double initiative. Si c'est le cas, une étape d’attribution des blessures de combat supplémentaire est créée juste pour elles. Les créatures avec l'initiative et la double initiative sont les seules à infliger des blessures de combat pendant cette étape. Ensuite, l'étape d'attribution des blessures de combat normale a lieu. Toutes les autres créatures attaquantes et bloqueuses qui ont survécu, ainsi que celles qui ont la double initiative, infligent des blessures de combat pendant cette deuxième étape."
  ),
  Keyword(
    term: "Enchanter",
    definition: "Toutes les auras ont cette capacité mot-clé, qui est toujours suivie du type de permanent auquel l'aura peut être attachée (par exemple « enchanter : créature » ou « enchanter : terrain »). Quand vous lancez l'aura, vous devez cibler ce type de permanent. Quand une capacité d'aura parle de « la créature enchantée », cela signifie : « la créature à laquelle l'aura est attachée. »"
  ),
  Keyword(
    term: "Équipement",
    definition: "Équipement est un sous-type qui apparaît sur un artefact qui peut être attaché à une créature. La plupart des cartes d’équipement ont la capacité activée « équipement » suivie d’un coût. Une capacité d'équipement ne peut être activée que lorsque vous pourriez lancer un rituel. Quand vous activez une capacité d’équipement, vous choisissez une créature que vous contrôlez comme cible. Quand la capacité se résout, l’artefact d’équipement devient attaché à cette créature."
  ),
  Keyword(
    term: "Initiative",
    definition: "Une capacité mot-clé trouvée sur des créatures. Les créatures qui ont l’initiative infligent toutes leurs blessures de combat avant les créatures qui ne l’ont pas ou qui n’ont pas la double initiative. Voir aussi Double Initiative."
  ),
  Keyword(
    term: "Vol",
    definition: "Une capacité mot-clé trouvée sur des créatures. Les créatures avec le vol peuvent uniquement être bloquées par des créatures avec le vol ou la portée."
  ),
  Keyword(
    term: "Célérité",
    definition: "Une capacité mot-clé trouvée sur des créatures. Une créature avec la célérité n’est pas affectée par le mal d'invocation. Elle peut attaquer dès le tour où elle arrive sous votre contrôle. Vous pouvez aussi activer ses capacités activées ayant le symbole d'engagement dans leur coût immédiatement."
  ),
  Keyword(
    term: "Lien de vie",
    definition: "Une capacité mot-clé trouvée sur des créatures. Quand une créature que vous contrôlez a le lien de vie et inflige des blessures, vous gagnez simultanément autant de points de vie."
  ),
  Keyword(
    term: "Portée",
    definition: "Une capacité mot-clé trouvée sur des créatures. Une créature avec la portée peut bloquer une créature avec le vol. Notez qu'une créature avec la portée peut être bloquée par n'importe quelle sorte de créature."
  ),
  Keyword(
    term: "Piétinement",
    definition: "Une capacité mot-clé trouvée sur des créatures. Le piétinement permet à une créature d'infliger un surplus de blessures de combat au joueur qu'elle attaque, même si elle est bloquée. Si vous attaquez avec une créature qui a le piétinement et qu’elle est bloquée, vous devez attribuer ses blessures de combat aux créatures qui la bloquent d’abord. Si elle détruit toutes ces créatures, vous pouvez attribuer le surplus de blessures au joueur qu’elle attaque."
  ),
  Keyword(
    term: " (Engager)",
    definition: "Ce symbole signifie « engagez ce permanent » (faites pivoter la carte à l'horizontale pour indiquer qu'elle a été utilisée). Il apparaît dans les coûts d’activation. Vous ne pouvez pas payer un coût d'engagement si la carte est déjà engagée, ou si c'est une créature qui souffre encore du mal d'invocation."
  ),
  Keyword(
    term: "Adversaire",
    definition: "La personne contre laquelle vous jouez est votre adversaire. Si une carte dit « un adversaire », cela signifie l'un des adversaires de son contrôleur."
  ),
  Keyword(
    term: "Aura",
    definition: "Aura est un sous-type qui apparaît sur un enchantement qui peut être attaché à un permanent. Chaque aura a le mot-clé « enchanter » suivi par la description de ce à quoi elle peut être attachée. Quand vous lancez un sort d’aura, vous choisissez sa cible. Quand l'aura se résout, elle est mise sur le champ de bataille, attachée à ce permanent."
  ),
  Keyword(
    term: "Défense Talismanique",
    definition: "Une capacité mot-clé qui empêche un permanent ou un joueur d'être la cible de sorts ou de capacités qu'un adversaire contrôle."
  ),
  Keyword(
    term: "Défenseur",
    definition: "Une capacité mot-clé trouvée sur des créatures. Les créatures qui ont le défenseur ne peuvent pas attaquer."
  ),
  Keyword(
    term: "Détruire",
    definition: "Quand un permanent est détruit, vous le déplacez du champ de bataille au cimetière de son propriétaire. Les créatures sont détruites lorsqu’elles subissent un nombre de blessures supérieur ou égal à leur endurance. De nombreux sorts et capacités peuvent également détruire des permanents sans leur infliger de blessures."
  ),
  Keyword(
    term: "Exil",
    definition: "Certains sorts et capacités peuvent exiler des permanents du champ de bataille ou des cartes d’autres zones. Les cartes exilées sont mises en dehors du reste de la partie. Vous ne pouvez pas interagir avec les cartes exilées à moins qu'une capacité ne spécifie le contraire."
  ),
  Keyword(
    term: "Flash",
    definition: "Une capacité mot-clé trouvée sur certaines cartes. Un sort avec le flash peut être lancé à tout moment où vous pourriez lancer un éphémère."
  ),
  Keyword(
    term: "Indestructible",
    definition: "Une capacité mot-clé. Un permanent indestructible ne peut pas être détruit par les blessures ou les effets qui indiquent « détruisez », mais il peut toujours être mis au cimetière pour d'autres raisons, comme un effet qui réduit son endurance à 0."
  ),
  Keyword(
    term: "Jeton",
    definition: "Certains sorts et capacités peuvent créer des jetons. Les jetons sont toujours des permanents. Cependant, si un de vos jetons quitte le champ de bataille, il va sur la nouvelle zone (par exemple votre cimetière ou votre main) et disparaît immédiatement de la partie."
  ),
  Keyword(
    term: "Légendaire",
    definition: "Légendaire est un super-type. Si un joueur contrôle au moins deux permanents légendaires du même nom au même moment, ce joueur doit choisir l'un de ces permanents à garder sur le champ de bataille et les autres sont immédiatement mis dans son cimetière."
  ),
  Keyword(
    term: "Mana",
    definition: "Le mana est l’unité de base d’énergie magique dont vous vous servez pour payer des sorts et certaines capacités. Le mana est généralement généré en engageant des terrains. Il y a cinq couleurs de mana : blanc, bleu, noir, rouge et vert. Le mana non dépensé disparaît à la fin des tours et des phases."
  ),
  Keyword(
    term: "Menace",
    definition: "Une capacité mot-clé trouvée sur des créatures. Une créature avec la menace ne peut pas être bloquée excepté par deux créatures ou plus."
  ),
  Keyword(
    term: "Mulligan",
    definition: "Au début de partie, si votre main de départ ne vous convient pas, vous pouvez déclarer un mulligan. Mélangez votre main dans votre bibliothèque puis piochez une nouvelle main de sept cartes. Si cette main vous convient, mettez une carte de cette main au-dessous de votre bibliothèque. Vous pouvez déclarer un mulligan autant de fois que vous le souhaitez, mais vous mettez une carte au-dessous de votre bibliothèque pour chaque mulligan que vous avez déclaré cette partie."
  ),
  Keyword(
    term: "Permanent",
    definition: "Une carte ou un jeton sur le champ de bataille. Les permanents peuvent être des artefacts, des créatures, des enchantements ou des terrains. Ils restent sur le champ de bataille jusqu'à ce qu'ils soient détruits, exilés, sacrifiés ou retirés."
  ),
  Keyword(
    term: "Planeswalker",
    definition: "Les planeswalkers sont de redoutables alliés que vous pouvez invoquer. Vous pouvez lancer un planeswalker pendant votre phase principale. Une fois par tour (pendant votre tour), vous pouvez activer une de leurs capacités en leur ajoutant ou en leur retirant des marqueurs « loyauté ». Quand la loyauté d'un planeswalker est réduite à zéro, il est envoyé au cimetière."
  ),
  Keyword(
    term: "Regard",
    definition: "Une action mot-clé. « Regard N » vous permet de regarder N cartes du dessus de votre bibliothèque. Vous pouvez mettre n’importe quel nombre de ces cartes au-dessous de votre bibliothèque, puis vous mettez le reste au-dessus de votre bibliothèque dans n’importe quel ordre."
  ),
  Keyword(
    term: "Sacrifier",
    definition: "Si un sort ou une capacité vous demande de sacrifier un type de permanent, choisissez un de vos permanents de ce type sur le champ de bataille et mettez-le dans le cimetière de son propriétaire. Vous ne pouvez sacrifier que les permanents que vous contrôlez."
  ),
  Keyword(
    term: "Se Défausser",
    definition: "Pour vous défausser d’une carte, prenez une carte de votre main et placez-la dans votre cimetière. Si vous avez plus de sept cartes en main à la fin de votre tour, vous devez vous défausser de cartes pour n’en avoir plus que sept."
  ),
  Keyword(
    term: "Sort",
    definition: "Tous les types de carte, à l'exception des terrains, sont des sorts au moment où vous les lancez. Les sorts ne peuvent être lancés que pendant votre phase principale, à l'exception des éphémères, qui peuvent être lancés à tout moment."
  ),
  Keyword(
    term: "Vigilance",
    definition: "Une capacité mot-clé trouvée sur des créatures. Une créature avec la vigilance ne s'engage pas pour attaquer."
  ),
  Keyword(
    term: "X",
    definition: "Quand vous voyez X dans un coût de mana ou un coût d’activation, vous pouvez choisir la valeur de X. Par exemple, un sort qui coûte X et R infligera X blessures. Si vous choisissez X=3, le sort coûtera 3 et R."
  ),
];