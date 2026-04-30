import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PassengerLanguage { english, french, kinyarwanda, swahili, spanish }

class PassengerLanguageService {
  PassengerLanguageService._();

  static const String _prefKey = 'passenger.language.code';
  static final PassengerLanguageService instance = PassengerLanguageService._();

  final ValueNotifier<PassengerLanguage> languageNotifier =
      ValueNotifier<PassengerLanguage>(PassengerLanguage.english);
  bool _isInitialized = false;

  static const Map<PassengerLanguage, String> _codes = {
    PassengerLanguage.english: 'en',
    PassengerLanguage.french: 'fr',
    PassengerLanguage.kinyarwanda: 'rw',
    PassengerLanguage.swahili: 'sw',
    PassengerLanguage.spanish: 'es',
  };

  static const Map<String, PassengerLanguage> _byCode = {
    'en': PassengerLanguage.english,
    'fr': PassengerLanguage.french,
    'rw': PassengerLanguage.kinyarwanda,
    'sw': PassengerLanguage.swahili,
    'es': PassengerLanguage.spanish,
  };

  static final Map<String, Map<PassengerLanguage, String>> _tr = {
    'nav.home': {
      PassengerLanguage.english: 'Home',
      PassengerLanguage.french: 'Accueil',
      PassengerLanguage.kinyarwanda: 'Ahabanza',
      PassengerLanguage.swahili: 'Nyumbani',
      PassengerLanguage.spanish: 'Inicio',
    },
    'nav.book': {
      PassengerLanguage.english: 'Book',
      PassengerLanguage.french: 'Réserver',
      PassengerLanguage.kinyarwanda: 'Tegura',
      PassengerLanguage.swahili: 'Agiza',
      PassengerLanguage.spanish: 'Reservar',
    },
    'nav.trips': {
      PassengerLanguage.english: 'Trips',
      PassengerLanguage.french: 'Trajets',
      PassengerLanguage.kinyarwanda: 'Ingendo',
      PassengerLanguage.swahili: 'Safari',
      PassengerLanguage.spanish: 'Viajes',
    },
    'nav.profile': {
      PassengerLanguage.english: 'Profile',
      PassengerLanguage.french: 'Profil',
      PassengerLanguage.kinyarwanda: 'Umwirondoro',
      PassengerLanguage.swahili: 'Wasifu',
      PassengerLanguage.spanish: 'Perfil',
    },
    'profile.title': {
      PassengerLanguage.english: 'Profile',
      PassengerLanguage.french: 'Profil',
      PassengerLanguage.kinyarwanda: 'Umwirondoro',
      PassengerLanguage.swahili: 'Wasifu',
      PassengerLanguage.spanish: 'Perfil',
    },
    'profile.verified': {
      PassengerLanguage.english: 'Verified Passenger',
      PassengerLanguage.french: 'Passager verifie',
      PassengerLanguage.kinyarwanda: 'Umugenzi Wemejwe',
      PassengerLanguage.swahili: 'Abiria Aliyethibitishwa',
      PassengerLanguage.spanish: 'Pasajero Verificado',
    },
    'profile.totalRides': {
      PassengerLanguage.english: 'Total Rides',
      PassengerLanguage.french: 'Total Trajets',
      PassengerLanguage.kinyarwanda: 'Ingendo Zose',
      PassengerLanguage.swahili: 'Jumla ya Safari',
      PassengerLanguage.spanish: 'Total de Viajes',
    },
    'profile.totalSpent': {
      PassengerLanguage.english: 'Total Spent',
      PassengerLanguage.french: 'Total Depense',
      PassengerLanguage.kinyarwanda: 'Amafaranga Yakoreshejwe',
      PassengerLanguage.swahili: 'Jumla Iliyotumika',
      PassengerLanguage.spanish: 'Total Gastado',
    },
    'profile.avgRating': {
      PassengerLanguage.english: 'Avg Rating',
      PassengerLanguage.french: 'Note Moyenne',
      PassengerLanguage.kinyarwanda: 'Amanota Impuzandengo',
      PassengerLanguage.swahili: 'Ukadiriaji wa Wastani',
      PassengerLanguage.spanish: 'Calificacion Promedio',
    },
    'profile.darkMode': {
      PassengerLanguage.english: 'Dark Mode',
      PassengerLanguage.french: 'Mode Sombre',
      PassengerLanguage.kinyarwanda: 'Uburyo Bwijimye',
      PassengerLanguage.swahili: 'Hali ya Giza',
      PassengerLanguage.spanish: 'Modo Oscuro',
    },
    'profile.pushNotifications': {
      PassengerLanguage.english: 'Push Notifications',
      PassengerLanguage.french: 'Notifications Push',
      PassengerLanguage.kinyarwanda: 'Amatangazo',
      PassengerLanguage.swahili: 'Arifa za Moja kwa Moja',
      PassengerLanguage.spanish: 'Notificaciones Push',
    },
    'profile.locationSharing': {
      PassengerLanguage.english: 'Location Sharing',
      PassengerLanguage.french: 'Partage de Position',
      PassengerLanguage.kinyarwanda: 'Gusangiza Ahantu',
      PassengerLanguage.swahili: 'Kushiriki Eneo',
      PassengerLanguage.spanish: 'Compartir Ubicacion',
    },
    'profile.logout': {
      PassengerLanguage.english: 'Log Out',
      PassengerLanguage.french: 'Se Deconnecter',
      PassengerLanguage.kinyarwanda: 'Sohoka',
      PassengerLanguage.swahili: 'Ondoka',
      PassengerLanguage.spanish: 'Cerrar Sesion',
    },
    'profile.logoutTitle': {
      PassengerLanguage.english: 'Log Out?',
      PassengerLanguage.french: 'Se Deconnecter?',
      PassengerLanguage.kinyarwanda: 'Urasohoka?',
      PassengerLanguage.swahili: 'Unataka Kuondoka?',
      PassengerLanguage.spanish: 'Cerrar Sesion?',
    },
    'profile.logoutBody': {
      PassengerLanguage.english:
          'Are you sure you want to log out of RideConnect?',
      PassengerLanguage.french:
          'Voulez-vous vraiment vous deconnecter de RideConnect?',
      PassengerLanguage.kinyarwanda: 'Urashaka gusohoka kuri RideConnect?',
      PassengerLanguage.swahili:
          'Una uhakika unataka kuondoka kwenye RideConnect?',
      PassengerLanguage.spanish:
          'Estas seguro de que deseas cerrar sesion en RideConnect?',
    },
    'common.cancel': {
      PassengerLanguage.english: 'Cancel',
      PassengerLanguage.french: 'Annuler',
      PassengerLanguage.kinyarwanda: 'Hagarika',
      PassengerLanguage.swahili: 'Ghairi',
      PassengerLanguage.spanish: 'Cancelar',
    },
    'settings.title': {
      PassengerLanguage.english: 'App Settings',
      PassengerLanguage.french: 'Parametres',
      PassengerLanguage.kinyarwanda: 'Igenamiterere',
      PassengerLanguage.swahili: 'Mipangilio',
      PassengerLanguage.spanish: 'Configuracion',
    },
    'settings.changePassword': {
      PassengerLanguage.english: 'Change password',
      PassengerLanguage.french: 'Changer le mot de passe',
      PassengerLanguage.kinyarwanda: 'Hindura ijambo banga',
      PassengerLanguage.swahili: 'Badilisha nenosiri',
      PassengerLanguage.spanish: 'Cambiar contrasena',
    },
    'settings.currentPassword': {
      PassengerLanguage.english: 'Current password',
      PassengerLanguage.french: 'Mot de passe actuel',
      PassengerLanguage.kinyarwanda: 'Ijambo banga rya none',
      PassengerLanguage.swahili: 'Nenosiri la sasa',
      PassengerLanguage.spanish: 'Contrasena actual',
    },
    'settings.newPassword': {
      PassengerLanguage.english: 'New password',
      PassengerLanguage.french: 'Nouveau mot de passe',
      PassengerLanguage.kinyarwanda: 'Ijambo banga rishya',
      PassengerLanguage.swahili: 'Nenosiri jipya',
      PassengerLanguage.spanish: 'Nueva contrasena',
    },
    'settings.confirmPassword': {
      PassengerLanguage.english: 'Confirm new password',
      PassengerLanguage.french: 'Confirmer le nouveau mot de passe',
      PassengerLanguage.kinyarwanda: 'Emeza ijambo banga rishya',
      PassengerLanguage.swahili: 'Thibitisha nenosiri jipya',
      PassengerLanguage.spanish: 'Confirmar nueva contrasena',
    },
    'settings.updatePassword': {
      PassengerLanguage.english: 'Update password',
      PassengerLanguage.french: 'Mettre a jour le mot de passe',
      PassengerLanguage.kinyarwanda: 'Vugurura ijambo banga',
      PassengerLanguage.swahili: 'Sasisha nenosiri',
      PassengerLanguage.spanish: 'Actualizar contrasena',
    },
    'settings.updatingPassword': {
      PassengerLanguage.english: 'Updating password...',
      PassengerLanguage.french: 'Mise a jour du mot de passe...',
      PassengerLanguage.kinyarwanda: 'Birimo kuvugurura ijambo banga...',
      PassengerLanguage.swahili: 'Inasasisha nenosiri...',
      PassengerLanguage.spanish: 'Actualizando contrasena...',
    },
    'settings.passwordRequired': {
      PassengerLanguage.english: 'All password fields are required.',
      PassengerLanguage.french:
          'Tous les champs de mot de passe sont obligatoires.',
      PassengerLanguage.kinyarwanda: 'Ibice byose by ijambo banga birasabwa.',
      PassengerLanguage.swahili: 'Sehemu zote za nenosiri zinahitajika.',
      PassengerLanguage.spanish:
          'Todos los campos de contrasena son obligatorios.',
    },
    'settings.passwordLength': {
      PassengerLanguage.english: 'New password must be at least 6 characters.',
      PassengerLanguage.french:
          'Le nouveau mot de passe doit contenir au moins 6 caracteres.',
      PassengerLanguage.kinyarwanda:
          'Ijambo banga rishya rigomba kuba rifite nibura inyuguti 6.',
      PassengerLanguage.swahili:
          'Nenosiri jipya lazima liwe na angalau herufi 6.',
      PassengerLanguage.spanish:
          'La nueva contrasena debe tener al menos 6 caracteres.',
    },
    'settings.passwordMismatch': {
      PassengerLanguage.english: 'New password and confirmation do not match.',
      PassengerLanguage.french:
          'Le nouveau mot de passe et sa confirmation ne correspondent pas.',
      PassengerLanguage.kinyarwanda:
          'Ijambo banga rishya n iryemeza ntibihura.',
      PassengerLanguage.swahili:
          'Nenosiri jipya na uthibitisho wake havilingani.',
      PassengerLanguage.spanish:
          'La nueva contrasena y su confirmacion no coinciden.',
    },
    'settings.passwordRelogin': {
      PassengerLanguage.english: 'Please login again to update password.',
      PassengerLanguage.french:
          'Veuillez vous reconnecter pour mettre a jour le mot de passe.',
      PassengerLanguage.kinyarwanda:
          'Injira bundi bushya kugira ngo uvugurure ijambo banga.',
      PassengerLanguage.swahili: 'Tafadhali ingia tena ili kusasisha nenosiri.',
      PassengerLanguage.spanish:
          'Inicia sesion de nuevo para actualizar la contrasena.',
    },
    'settings.passwordUpdated': {
      PassengerLanguage.english: 'Password updated successfully.',
      PassengerLanguage.french: 'Mot de passe mis a jour avec succes.',
      PassengerLanguage.kinyarwanda: 'Ijambo banga ryavuguruwe neza.',
      PassengerLanguage.swahili: 'Nenosiri limesasishwa kikamilifu.',
      PassengerLanguage.spanish: 'Contrasena actualizada correctamente.',
    },
    'settings.language': {
      PassengerLanguage.english: 'Language',
      PassengerLanguage.french: 'Langue',
      PassengerLanguage.kinyarwanda: 'Ururimi',
      PassengerLanguage.swahili: 'Lugha',
      PassengerLanguage.spanish: 'Idioma',
    },
    'settings.editProfile': {
      PassengerLanguage.english: 'Edit Profile',
      PassengerLanguage.french: 'Modifier Profil',
      PassengerLanguage.kinyarwanda: 'Hindura Umwirondoro',
      PassengerLanguage.swahili: 'Hariri Wasifu',
      PassengerLanguage.spanish: 'Editar Perfil',
    },
    'settings.paymentMethods': {
      PassengerLanguage.english: 'Payment Methods',
      PassengerLanguage.french: 'Moyens de Paiement',
      PassengerLanguage.kinyarwanda: 'Uburyo bwo Kwishyura',
      PassengerLanguage.swahili: 'Njia za Malipo',
      PassengerLanguage.spanish: 'Metodos de Pago',
    },
    'settings.ridePreferences': {
      PassengerLanguage.english: 'Ride Preferences',
      PassengerLanguage.french: 'Preferences de Trajet',
      PassengerLanguage.kinyarwanda: 'Ibyifuzo by Urugendo',
      PassengerLanguage.swahili: 'Mapendeleo ya Safari',
      PassengerLanguage.spanish: 'Preferencias de Viaje',
    },
    'settings.help': {
      PassengerLanguage.english: 'Help & Support',
      PassengerLanguage.french: 'Aide & Support',
      PassengerLanguage.kinyarwanda: 'Ubufasha',
      PassengerLanguage.swahili: 'Msaada',
      PassengerLanguage.spanish: 'Ayuda y Soporte',
    },
    'settings.privacy': {
      PassengerLanguage.english: 'Privacy Policy',
      PassengerLanguage.french: 'Politique de Confidentialite',
      PassengerLanguage.kinyarwanda: 'Politiki y Ibanga',
      PassengerLanguage.swahili: 'Sera ya Faragha',
      PassengerLanguage.spanish: 'Politica de Privacidad',
    },
    'settings.rate': {
      PassengerLanguage.english: 'Rate RideConnect',
      PassengerLanguage.french: 'Noter RideConnect',
      PassengerLanguage.kinyarwanda: 'Tanga Amanota kuri RideConnect',
      PassengerLanguage.swahili: 'Kadiria RideConnect',
      PassengerLanguage.spanish: 'Calificar RideConnect',
    },
    'home.greeting': {
      PassengerLanguage.english: 'Hello, {name}!',
      PassengerLanguage.french: 'Bonjour, {name}!',
      PassengerLanguage.kinyarwanda: 'Muraho, {name}!',
      PassengerLanguage.swahili: 'Habari, {name}!',
      PassengerLanguage.spanish: 'Hola, {name}!',
    },
    'home.whereTo': {
      PassengerLanguage.english: 'Where are you heading today?',
      PassengerLanguage.french: 'Ou allez-vous aujourd hui?',
      PassengerLanguage.kinyarwanda: 'Uyu munsi ujya he?',
      PassengerLanguage.swahili: 'Unaelekea wapi leo?',
      PassengerLanguage.spanish: 'A donde vas hoy?',
    },
    'home.quickRideOptions': {
      PassengerLanguage.english: 'Quick Ride Options',
      PassengerLanguage.french: 'Options de trajet rapide',
      PassengerLanguage.kinyarwanda: 'Amahitamo y urugendo rwihuse',
      PassengerLanguage.swahili: 'Chaguo za safari za haraka',
      PassengerLanguage.spanish: 'Opciones rapidas de viaje',
    },
    'home.rideType': {
      PassengerLanguage.english: 'Ride Type',
      PassengerLanguage.french: 'Type de trajet',
      PassengerLanguage.kinyarwanda: 'Ubwoko bw urugendo',
      PassengerLanguage.swahili: 'Aina ya safari',
      PassengerLanguage.spanish: 'Tipo de viaje',
    },
    'home.private': {
      PassengerLanguage.english: 'Private',
      PassengerLanguage.french: 'Prive',
      PassengerLanguage.kinyarwanda: 'Privee',
      PassengerLanguage.swahili: 'Binafsi',
      PassengerLanguage.spanish: 'Privado',
    },
    'home.privateDesc': {
      PassengerLanguage.english: 'Just for you',
      PassengerLanguage.french: 'Juste pour vous',
      PassengerLanguage.kinyarwanda: 'Gusa kwawe',
      PassengerLanguage.swahili: 'Ni kwako tu',
      PassengerLanguage.spanish: 'Solo para ti',
    },
    'home.public': {
      PassengerLanguage.english: 'Public',
      PassengerLanguage.french: 'Public',
      PassengerLanguage.kinyarwanda: 'Rusange',
      PassengerLanguage.swahili: 'Umma',
      PassengerLanguage.spanish: 'Publico',
    },
    'home.publicDesc': {
      PassengerLanguage.english: 'Share & save',
      PassengerLanguage.french: 'Partagez et economisez',
      PassengerLanguage.kinyarwanda: 'Gabanya kandi eza',
      PassengerLanguage.swahili: 'Shiriki na kuokoa',
      PassengerLanguage.spanish: 'Comparte y ahorra',
    },
    'home.nearbyDrivers': {
      PassengerLanguage.english: 'Nearby Drivers',
      PassengerLanguage.french: 'Chauffeurs proches',
      PassengerLanguage.kinyarwanda: 'Abashoferi hafi',
      PassengerLanguage.swahili: 'Madereva wa karibu',
      PassengerLanguage.spanish: 'Conductores cercanos',
    },
    'home.seeAll': {
      PassengerLanguage.english: 'See All',
      PassengerLanguage.french: 'Voir tout',
      PassengerLanguage.kinyarwanda: 'Reba byose',
      PassengerLanguage.swahili: 'Ona zote',
      PassengerLanguage.spanish: 'Ver todo',
    },
    'home.searchPrompt': {
      PassengerLanguage.english: 'Where are you going?',
      PassengerLanguage.french: 'Ou allez-vous?',
      PassengerLanguage.kinyarwanda: 'Ujya he?',
      PassengerLanguage.swahili: 'Unaenda wapi?',
      PassengerLanguage.spanish: 'A donde vas?',
    },
    'home.searchSubPrompt': {
      PassengerLanguage.english: 'Tap to search your destination',
      PassengerLanguage.french: 'Touchez pour rechercher votre destination',
      PassengerLanguage.kinyarwanda: 'Kanda ushakishe aho ujya',
      PassengerLanguage.swahili: 'Gusa kutafuta unakoenda',
      PassengerLanguage.spanish: 'Toca para buscar tu destino',
    },
    'home.savedPlaces': {
      PassengerLanguage.english: 'Saved Places',
      PassengerLanguage.french: 'Lieux enregistres',
      PassengerLanguage.kinyarwanda: 'Ahantu habitse',
      PassengerLanguage.swahili: 'Maeneo yaliyohifadhiwa',
      PassengerLanguage.spanish: 'Lugares guardados',
    },
    'home.addPlace': {
      PassengerLanguage.english: '+ Add Place',
      PassengerLanguage.french: '+ Ajouter un lieu',
      PassengerLanguage.kinyarwanda: '+ Ongeraho ahantu',
      PassengerLanguage.swahili: '+ Ongeza eneo',
      PassengerLanguage.spanish: '+ Agregar lugar',
    },
    'home.mapOverview': {
      PassengerLanguage.english: 'Map Overview',
      PassengerLanguage.french: 'Apercu de la carte',
      PassengerLanguage.kinyarwanda: 'Incamake y ikarita',
      PassengerLanguage.swahili: 'Muhtasari wa ramani',
      PassengerLanguage.spanish: 'Resumen del mapa',
    },
    'home.driversNearby': {
      PassengerLanguage.english: '3 drivers nearby',
      PassengerLanguage.french: '3 chauffeurs proches',
      PassengerLanguage.kinyarwanda: 'Abashoferi 3 hafi',
      PassengerLanguage.swahili: 'Madereva 3 karibu',
      PassengerLanguage.spanish: '3 conductores cerca',
    },
    'home.yourLocation': {
      PassengerLanguage.english: 'Your Location',
      PassengerLanguage.french: 'Votre position',
      PassengerLanguage.kinyarwanda: 'Aho uri',
      PassengerLanguage.swahili: 'Mahali ulipo',
      PassengerLanguage.spanish: 'Tu ubicacion',
    },
    'book.title': {
      PassengerLanguage.english: 'Book a Ride',
      PassengerLanguage.french: 'Reserver un trajet',
      PassengerLanguage.kinyarwanda: 'Tegura urugendo',
      PassengerLanguage.swahili: 'Agiza Safari',
      PassengerLanguage.spanish: 'Reservar un Viaje',
    },
    'book.scheduled': {
      PassengerLanguage.english: 'Scheduled',
      PassengerLanguage.french: 'Planifie',
      PassengerLanguage.kinyarwanda: 'Byateganyijwe',
      PassengerLanguage.swahili: 'Iliyopangwa',
      PassengerLanguage.spanish: 'Programado',
    },
    'book.immediate': {
      PassengerLanguage.english: 'Immediate',
      PassengerLanguage.french: 'Immediat',
      PassengerLanguage.kinyarwanda: 'Ako kanya',
      PassengerLanguage.swahili: 'Mara moja',
      PassengerLanguage.spanish: 'Inmediato',
    },
    'book.enterPickup': {
      PassengerLanguage.english: 'Please enter a pickup address',
      PassengerLanguage.french: 'Veuillez saisir une adresse de depart',
      PassengerLanguage.kinyarwanda: 'Andika aho bagufatira',
      PassengerLanguage.swahili: 'Tafadhali weka anwani ya kuchukulia',
      PassengerLanguage.spanish: 'Ingresa una direccion de recogida',
    },
    'book.enterDropoff': {
      PassengerLanguage.english: 'Please enter a dropoff address',
      PassengerLanguage.french: 'Veuillez saisir une adresse de destination',
      PassengerLanguage.kinyarwanda: 'Andika aho ujya',
      PassengerLanguage.swahili: 'Tafadhali weka anwani ya kushuka',
      PassengerLanguage.spanish: 'Ingresa una direccion de destino',
    },
    'book.seatRangeError': {
      PassengerLanguage.english: 'Seats must be between 1 and 8',
      PassengerLanguage.french: 'Le nombre de places doit etre entre 1 et 8',
      PassengerLanguage.kinyarwanda: 'Intebe zigomba kuba hagati ya 1 na 8',
      PassengerLanguage.swahili: 'Viti lazima viwe kati ya 1 na 8',
      PassengerLanguage.spanish: 'Los asientos deben estar entre 1 y 8',
    },
    'book.noRideIdError': {
      PassengerLanguage.english:
          'No backend ride_id found. Refresh available rides and try again.',
      PassengerLanguage.french:
          'Aucun ride_id trouve. Actualisez les trajets disponibles et reessayez.',
      PassengerLanguage.kinyarwanda:
          'Nta ride_id yabonetse. Ongera ushyire ku rutonde rw ingendo maze wongere ugerageze.',
      PassengerLanguage.swahili:
          'Hakuna ride_id iliyopatikana. Sasisha safari zilizopo kisha ujaribu tena.',
      PassengerLanguage.spanish:
          'No se encontro ride_id. Actualiza los viajes disponibles e intentalo de nuevo.',
    },
    'book.rideRequestedTitle': {
      PassengerLanguage.english: 'Ride Requested!',
      PassengerLanguage.french: 'Trajet demande!',
      PassengerLanguage.kinyarwanda: 'Urugendo rwasabwe!',
      PassengerLanguage.swahili: 'Safari imeombwa!',
      PassengerLanguage.spanish: 'Viaje solicitado!',
    },
    'book.rideRequestedBody': {
      PassengerLanguage.english:
          'Your {ride} ride is confirmed.\nA driver will arrive in {eta}.',
      PassengerLanguage.french:
          'Votre trajet {ride} est confirme.\nUn chauffeur arrivera dans {eta}.',
      PassengerLanguage.kinyarwanda:
          'Urugendo rwawe rwa {ride} rwemejwe.\nUmushoferi araza mu gihe cya {eta}.',
      PassengerLanguage.swahili:
          'Safari yako ya {ride} imethibitishwa.\nDereva atafika ndani ya {eta}.',
      PassengerLanguage.spanish:
          'Tu viaje de tipo {ride} esta confirmado.\nUn conductor llegara en {eta}.',
    },
    'book.estimatedFare': {
      PassengerLanguage.english: 'Estimated Fare',
      PassengerLanguage.french: 'Tarif estime',
      PassengerLanguage.kinyarwanda: 'Igiciro giteganyijwe',
      PassengerLanguage.swahili: 'Nauli inayokadiriwa',
      PassengerLanguage.spanish: 'Tarifa estimada',
    },
    'book.eta': {
      PassengerLanguage.english: 'ETA',
      PassengerLanguage.french: 'Heure d arrivee',
      PassengerLanguage.kinyarwanda: 'Igihe cyo kugera',
      PassengerLanguage.swahili: 'Muda wa kufika',
      PassengerLanguage.spanish: 'Hora estimada de llegada',
    },
    'book.seats': {
      PassengerLanguage.english: 'Seats',
      PassengerLanguage.french: 'Places',
      PassengerLanguage.kinyarwanda: 'Intebe',
      PassengerLanguage.swahili: 'Viti',
      PassengerLanguage.spanish: 'Asientos',
    },
    'book.destination': {
      PassengerLanguage.english: 'Destination',
      PassengerLanguage.french: 'Destination',
      PassengerLanguage.kinyarwanda: 'Aho ujya',
      PassengerLanguage.swahili: 'Unakoenda',
      PassengerLanguage.spanish: 'Destino',
    },
    'book.trackDriver': {
      PassengerLanguage.english: 'Track Driver',
      PassengerLanguage.french: 'Suivre le chauffeur',
      PassengerLanguage.kinyarwanda: 'Kurikirana umushoferi',
      PassengerLanguage.swahili: 'Fuatilia dereva',
      PassengerLanguage.spanish: 'Seguir conductor',
    },
    'book.tapToSetOnMap': {
      PassengerLanguage.english: 'Tap to set on map',
      PassengerLanguage.french: 'Touchez pour definir sur la carte',
      PassengerLanguage.kinyarwanda: 'Kanda ushyire ku ikarita',
      PassengerLanguage.swahili: 'Gusa kuweka kwenye ramani',
      PassengerLanguage.spanish: 'Toca para fijar en el mapa',
    },
    'book.pickupHint': {
      PassengerLanguage.english: 'Pickup location',
      PassengerLanguage.french: 'Lieu de depart',
      PassengerLanguage.kinyarwanda: 'Aho bagufatira',
      PassengerLanguage.swahili: 'Mahali pa kuchukulia',
      PassengerLanguage.spanish: 'Lugar de recogida',
    },
    'book.dropoffHint': {
      PassengerLanguage.english: 'Dropoff address',
      PassengerLanguage.french: 'Adresse de destination',
      PassengerLanguage.kinyarwanda: 'Aho ujya',
      PassengerLanguage.swahili: 'Anwani ya kushuka',
      PassengerLanguage.spanish: 'Direccion de destino',
    },
    'book.seatsHint': {
      PassengerLanguage.english: 'Seats (1-8)',
      PassengerLanguage.french: 'Places (1-8)',
      PassengerLanguage.kinyarwanda: 'Intebe (1-8)',
      PassengerLanguage.swahili: 'Viti (1-8)',
      PassengerLanguage.spanish: 'Asientos (1-8)',
    },
    'book.chooseRideType': {
      PassengerLanguage.english: 'Choose Ride Type',
      PassengerLanguage.french: 'Choisir le type de trajet',
      PassengerLanguage.kinyarwanda: 'Hitamo ubwoko bw urugendo',
      PassengerLanguage.swahili: 'Chagua aina ya safari',
      PassengerLanguage.spanish: 'Elige tipo de viaje',
    },
    'book.estimatedArrival': {
      PassengerLanguage.english: 'Estimated Arrival',
      PassengerLanguage.french: 'Arrivee estimee',
      PassengerLanguage.kinyarwanda: 'Igihe cyo kugera giteganyijwe',
      PassengerLanguage.swahili: 'Muda wa kufika unaokadiriwa',
      PassengerLanguage.spanish: 'Llegada estimada',
    },
    'book.rideType': {
      PassengerLanguage.english: 'Ride Type',
      PassengerLanguage.french: 'Type de trajet',
      PassengerLanguage.kinyarwanda: 'Ubwoko bw urugendo',
      PassengerLanguage.swahili: 'Aina ya safari',
      PassengerLanguage.spanish: 'Tipo de viaje',
    },
    'book.findingDriver': {
      PassengerLanguage.english: 'Finding Driver...',
      PassengerLanguage.french: 'Recherche du chauffeur...',
      PassengerLanguage.kinyarwanda: 'Turimo gushaka umushoferi...',
      PassengerLanguage.swahili: 'Inatafuta dereva...',
      PassengerLanguage.spanish: 'Buscando conductor...',
    },
    'book.requestRide': {
      PassengerLanguage.english: 'Request Ride',
      PassengerLanguage.french: 'Demander un trajet',
      PassengerLanguage.kinyarwanda: 'Saba urugendo',
      PassengerLanguage.swahili: 'Omba safari',
      PassengerLanguage.spanish: 'Solicitar viaje',
    },
    'book.currentLocation': {
      PassengerLanguage.english: 'Current Location',
      PassengerLanguage.french: 'Position actuelle',
      PassengerLanguage.kinyarwanda: 'Aho uri ubu',
      PassengerLanguage.swahili: 'Eneo la sasa',
      PassengerLanguage.spanish: 'Ubicacion actual',
    },
    'book.locatingAddress': {
      PassengerLanguage.english: 'Locating address...',
      PassengerLanguage.french: 'Localisation de l adresse...',
      PassengerLanguage.kinyarwanda: 'Birimo gushaka aderesi...',
      PassengerLanguage.swahili: 'Inatafuta anwani...',
      PassengerLanguage.spanish: 'Buscando direccion...',
    },
    'book.availableSeatsOnly': {
      PassengerLanguage.english:
          'Only {count} seat(s) are currently available for this ride.',
      PassengerLanguage.french:
          'Seulement {count} place(s) sont actuellement disponibles pour ce trajet.',
      PassengerLanguage.kinyarwanda:
          'Intebe {count} gusa ni zo zihari kuri uru rugendo ubu.',
      PassengerLanguage.swahili:
          'Ni kiti {count} tu vinapatikana kwa safari hii kwa sasa.',
      PassengerLanguage.spanish:
          'Solo hay {count} asiento(s) disponibles para este viaje ahora.',
    },
    'book.noBookingToPay': {
      PassengerLanguage.english: 'No booking found to pay for yet.',
      PassengerLanguage.french: 'Aucune reservation a payer pour le moment.',
      PassengerLanguage.kinyarwanda: 'Nta booking iraboneka yo kwishyura ubu.',
      PassengerLanguage.swahili: 'Hakuna booking ya kulipia kwa sasa.',
      PassengerLanguage.spanish: 'Aun no hay reserva para pagar.',
    },
    'book.invalidBookingAmount': {
      PassengerLanguage.english: 'The booking amount is invalid for payment.',
      PassengerLanguage.french:
          'Le montant de la reservation est invalide pour le paiement.',
      PassengerLanguage.kinyarwanda:
          'Amafaranga ya booking si yo kugira ngo hishyurwe.',
      PassengerLanguage.swahili: 'Kiasi cha booking si sahihi kwa malipo.',
      PassengerLanguage.spanish:
          'El monto de la reserva no es valido para el pago.',
    },
    'book.paymentMethod': {
      PassengerLanguage.english: 'Payment method',
      PassengerLanguage.french: 'Methode de paiement',
      PassengerLanguage.kinyarwanda: 'Uburyo bwo kwishyura',
      PassengerLanguage.swahili: 'Njia ya malipo',
      PassengerLanguage.spanish: 'Metodo de pago',
    },
    'book.processingPayment': {
      PassengerLanguage.english: 'Processing {method} payment...',
      PassengerLanguage.french: 'Traitement du paiement {method}...',
      PassengerLanguage.kinyarwanda:
          'Birimo gutunganya kwishyura kwa {method}...',
      PassengerLanguage.swahili: 'Inachakata malipo ya {method}...',
      PassengerLanguage.spanish: 'Procesando pago de {method}...',
    },
    'book.payNowWithMethod': {
      PassengerLanguage.english: 'Pay now ({method})',
      PassengerLanguage.french: 'Payer maintenant ({method})',
      PassengerLanguage.kinyarwanda: 'Ishyure nonaha ({method})',
      PassengerLanguage.swahili: 'Lipa sasa ({method})',
      PassengerLanguage.spanish: 'Pagar ahora ({method})',
    },
    'book.paymentStatus': {
      PassengerLanguage.english: 'Payment {status}.',
      PassengerLanguage.french: 'Paiement {status}.',
      PassengerLanguage.kinyarwanda: 'Kwishyura {status}.',
      PassengerLanguage.swahili: 'Malipo {status}.',
      PassengerLanguage.spanish: 'Pago {status}.',
    },
    'payment.cash': {
      PassengerLanguage.english: 'cash',
      PassengerLanguage.french: 'especes',
      PassengerLanguage.kinyarwanda: 'cash',
      PassengerLanguage.swahili: 'fedha taslimu',
      PassengerLanguage.spanish: 'efectivo',
    },
    'payment.mobileMoney': {
      PassengerLanguage.english: 'mobile money',
      PassengerLanguage.french: 'mobile money',
      PassengerLanguage.kinyarwanda: 'mobile money',
      PassengerLanguage.swahili: 'pesa ya simu',
      PassengerLanguage.spanish: 'dinero movil',
    },
    'payment.card': {
      PassengerLanguage.english: 'card',
      PassengerLanguage.french: 'carte',
      PassengerLanguage.kinyarwanda: 'ikarita',
      PassengerLanguage.swahili: 'kadi',
      PassengerLanguage.spanish: 'tarjeta',
    },
    'trips.title': {
      PassengerLanguage.english: 'Trips',
      PassengerLanguage.french: 'Trajets',
      PassengerLanguage.kinyarwanda: 'Ingendo',
      PassengerLanguage.swahili: 'Safari',
      PassengerLanguage.spanish: 'Viajes',
    },
    'trips.myTrips': {
      PassengerLanguage.english: 'My Trips',
      PassengerLanguage.french: 'Mes trajets',
      PassengerLanguage.kinyarwanda: 'Ingendo zanjye',
      PassengerLanguage.swahili: 'Safari zangu',
      PassengerLanguage.spanish: 'Mis viajes',
    },
    'trips.history': {
      PassengerLanguage.english: 'History',
      PassengerLanguage.french: 'Historique',
      PassengerLanguage.kinyarwanda: 'Amateka',
      PassengerLanguage.swahili: 'Historia',
      PassengerLanguage.spanish: 'Historial',
    },
    'trips.totalTrips': {
      PassengerLanguage.english: 'Total Trips',
      PassengerLanguage.french: 'Total trajets',
      PassengerLanguage.kinyarwanda: 'Ingendo zose',
      PassengerLanguage.swahili: 'Jumla ya safari',
      PassengerLanguage.spanish: 'Viajes totales',
    },
    'trips.totalSpent': {
      PassengerLanguage.english: 'Total Spent',
      PassengerLanguage.french: 'Total depense',
      PassengerLanguage.kinyarwanda: 'Amafaranga yose',
      PassengerLanguage.swahili: 'Jumla iliyotumika',
      PassengerLanguage.spanish: 'Total gastado',
    },
    'trips.status': {
      PassengerLanguage.english: 'Status',
      PassengerLanguage.french: 'Statut',
      PassengerLanguage.kinyarwanda: 'Imiterere',
      PassengerLanguage.swahili: 'Hali',
      PassengerLanguage.spanish: 'Estado',
    },
    'trips.perPage': {
      PassengerLanguage.english: 'Per page',
      PassengerLanguage.french: 'Par page',
      PassengerLanguage.kinyarwanda: 'Kuri paji',
      PassengerLanguage.swahili: 'Kwa ukurasa',
      PassengerLanguage.spanish: 'Por pagina',
    },
    'trips.startDate': {
      PassengerLanguage.english: 'Start date',
      PassengerLanguage.french: 'Date debut',
      PassengerLanguage.kinyarwanda: 'Itariki yo gutangira',
      PassengerLanguage.swahili: 'Tarehe ya kuanza',
      PassengerLanguage.spanish: 'Fecha de inicio',
    },
    'trips.endDate': {
      PassengerLanguage.english: 'End date',
      PassengerLanguage.french: 'Date fin',
      PassengerLanguage.kinyarwanda: 'Itariki yo kurangiza',
      PassengerLanguage.swahili: 'Tarehe ya mwisho',
      PassengerLanguage.spanish: 'Fecha final',
    },
    'trips.date': {
      PassengerLanguage.english: 'Date',
      PassengerLanguage.french: 'Date',
      PassengerLanguage.kinyarwanda: 'Itariki',
      PassengerLanguage.swahili: 'Tarehe',
      PassengerLanguage.spanish: 'Fecha',
    },
    'trips.empty': {
      PassengerLanguage.english: 'No trips here',
      PassengerLanguage.french: 'Aucun trajet ici',
      PassengerLanguage.kinyarwanda: 'Nta ngendo hano',
      PassengerLanguage.swahili: 'Hakuna safari hapa',
      PassengerLanguage.spanish: 'No hay viajes aqui',
    },
    'trips.detailsUnavailable': {
      PassengerLanguage.english: 'Ride details are unavailable.',
      PassengerLanguage.french: 'Les details du trajet sont indisponibles.',
      PassengerLanguage.kinyarwanda: 'Amakuru y urugendo ntaboneka.',
      PassengerLanguage.swahili: 'Maelezo ya safari hayapatikani.',
      PassengerLanguage.spanish: 'Los detalles del viaje no estan disponibles.',
    },
    'trips.loadFailed': {
      PassengerLanguage.english: 'Failed to load trips. {error}',
      PassengerLanguage.french: 'Echec du chargement des trajets. {error}',
      PassengerLanguage.kinyarwanda:
          'Ntibyashobotse gutangiza ingendo. {error}',
      PassengerLanguage.swahili: 'Imeshindikana kupakia safari. {error}',
      PassengerLanguage.spanish: 'No se pudieron cargar los viajes. {error}',
    },
    'trips.historyConflict': {
      PassengerLanguage.english:
          'History endpoint has a backend route conflict right now. Active trips are still live.',
      PassengerLanguage.french:
          'Le point historique a un conflit de route. Les trajets actifs restent disponibles.',
      PassengerLanguage.kinyarwanda:
          'Urupapuro rw amateka rufite ikibazo cya route. Ingendo zikora ziracyaboneka.',
      PassengerLanguage.swahili:
          'History endpoint ina mgongano wa route. Safari zinazoendelea bado zipo.',
      PassengerLanguage.spanish:
          'El endpoint de historial tiene conflicto de ruta. Los viajes activos siguen en linea.',
    },
    'trips.bookingUpdated': {
      PassengerLanguage.english: 'Booking submitted. Active trips updated.',
      PassengerLanguage.french:
          'Reservation envoyee. Les trajets actifs ont ete mis a jour.',
      PassengerLanguage.kinyarwanda:
          'Gusaba byoherejwe. Ingendo zikora zavuguruwe.',
      PassengerLanguage.swahili:
          'Ombi la kuhifadhi limetumwa. Safari zinazoendelea zimesasishwa.',
      PassengerLanguage.spanish:
          'Reserva enviada. Los viajes activos se actualizaron.',
    },
    'trips.backendQueryPreview': {
      PassengerLanguage.english: 'Backend Query Preview',
      PassengerLanguage.french: 'Apercu de requete backend',
      PassengerLanguage.kinyarwanda: 'Igaragaza rya query ya backend',
      PassengerLanguage.swahili: 'Muhtasari wa swali la backend',
      PassengerLanguage.spanish: 'Vista previa de consulta backend',
    },
    'trips.cancelRide': {
      PassengerLanguage.english: 'Cancel Ride',
      PassengerLanguage.french: 'Annuler le trajet',
      PassengerLanguage.kinyarwanda: 'Hagarika urugendo',
      PassengerLanguage.swahili: 'Ghairi safari',
      PassengerLanguage.spanish: 'Cancelar viaje',
    },
    'trips.tapForDetails': {
      PassengerLanguage.english: 'Tap card for trip details',
      PassengerLanguage.french: 'Touchez la carte pour les details',
      PassengerLanguage.kinyarwanda: 'Kanda ikarita urebe amakuru y urugendo',
      PassengerLanguage.swahili: 'Gusa kadi kuona maelezo ya safari',
      PassengerLanguage.spanish: 'Toca la tarjeta para ver detalles',
    },
    'trips.requested': {
      PassengerLanguage.english: 'Requested',
      PassengerLanguage.french: 'Demande',
      PassengerLanguage.kinyarwanda: 'Byasabye',
      PassengerLanguage.swahili: 'Imeombwa',
      PassengerLanguage.spanish: 'Solicitado',
    },
    'trips.inProgress': {
      PassengerLanguage.english: 'In Progress',
      PassengerLanguage.french: 'En cours',
      PassengerLanguage.kinyarwanda: 'Birakomeje',
      PassengerLanguage.swahili: 'Inaendelea',
      PassengerLanguage.spanish: 'En progreso',
    },
    'trips.trip': {
      PassengerLanguage.english: 'Trip',
      PassengerLanguage.french: 'Trajet',
      PassengerLanguage.kinyarwanda: 'Urugendo',
      PassengerLanguage.swahili: 'Safari',
      PassengerLanguage.spanish: 'Viaje',
    },
    'trips.fare': {
      PassengerLanguage.english: 'Fare',
      PassengerLanguage.french: 'Tarif',
      PassengerLanguage.kinyarwanda: 'Igiciro',
      PassengerLanguage.swahili: 'Nauli',
      PassengerLanguage.spanish: 'Tarifa',
    },
    'trips.payment': {
      PassengerLanguage.english: 'Payment',
      PassengerLanguage.french: 'Paiement',
      PassengerLanguage.kinyarwanda: 'Kwishyura',
      PassengerLanguage.swahili: 'Malipo',
      PassengerLanguage.spanish: 'Pago',
    },
    'trips.progress': {
      PassengerLanguage.english: 'Trip Progress',
      PassengerLanguage.french: 'Progression du trajet',
      PassengerLanguage.kinyarwanda: 'Aho urugendo rugeze',
      PassengerLanguage.swahili: 'Maendeleo ya safari',
      PassengerLanguage.spanish: 'Progreso del viaje',
    },
    'trips.driver': {
      PassengerLanguage.english: 'Driver',
      PassengerLanguage.french: 'Chauffeur',
      PassengerLanguage.kinyarwanda: 'Umushoferi',
      PassengerLanguage.swahili: 'Dereva',
      PassengerLanguage.spanish: 'Conductor',
    },
    'trips.pickup': {
      PassengerLanguage.english: 'Pickup',
      PassengerLanguage.french: 'Depart',
      PassengerLanguage.kinyarwanda: 'Aho bagufatira',
      PassengerLanguage.swahili: 'Kuchukulia',
      PassengerLanguage.spanish: 'Recogida',
    },
    'trips.dropoff': {
      PassengerLanguage.english: 'Dropoff',
      PassengerLanguage.french: 'Destination',
      PassengerLanguage.kinyarwanda: 'Aho ujya',
      PassengerLanguage.swahili: 'Kushuka',
      PassengerLanguage.spanish: 'Destino',
    },
    'trips.notes': {
      PassengerLanguage.english: 'Notes',
      PassengerLanguage.french: 'Notes',
      PassengerLanguage.kinyarwanda: 'Ibisobanuro',
      PassengerLanguage.swahili: 'Maelezo',
      PassengerLanguage.spanish: 'Notas',
    },
    'trips.rebookRoute': {
      PassengerLanguage.english: 'Rebook This Route',
      PassengerLanguage.french: 'Reserver de nouveau cet itineraire',
      PassengerLanguage.kinyarwanda: 'Ongera utegure iyi nzira',
      PassengerLanguage.swahili: 'Hifadhi tena njia hii',
      PassengerLanguage.spanish: 'Reservar de nuevo esta ruta',
    },
    'trips.rateDriver': {
      PassengerLanguage.english: 'Rate driver:',
      PassengerLanguage.french: 'Noter le chauffeur :',
      PassengerLanguage.kinyarwanda: 'Ha amanota umushoferi:',
      PassengerLanguage.swahili: 'Kadiria dereva:',
      PassengerLanguage.spanish: 'Califica al conductor:',
    },
    'trips.yourRating': {
      PassengerLanguage.english: 'Your rating:',
      PassengerLanguage.french: 'Votre note :',
      PassengerLanguage.kinyarwanda: 'Amanota yawe:',
      PassengerLanguage.swahili: 'Ukadiriaji wako:',
      PassengerLanguage.spanish: 'Tu calificacion:',
    },
    'status.active': {
      PassengerLanguage.english: 'Active',
      PassengerLanguage.french: 'Actif',
      PassengerLanguage.kinyarwanda: 'Birakora',
      PassengerLanguage.swahili: 'Inaendelea',
      PassengerLanguage.spanish: 'Activo',
    },
    'status.completed': {
      PassengerLanguage.english: 'Completed',
      PassengerLanguage.french: 'Termine',
      PassengerLanguage.kinyarwanda: 'Byarangiye',
      PassengerLanguage.swahili: 'Imekamilika',
      PassengerLanguage.spanish: 'Completado',
    },
    'status.cancelled': {
      PassengerLanguage.english: 'Cancelled',
      PassengerLanguage.french: 'Annule',
      PassengerLanguage.kinyarwanda: 'Byahagaritswe',
      PassengerLanguage.swahili: 'Imeghairiwa',
      PassengerLanguage.spanish: 'Cancelado',
    },
    'common.all': {
      PassengerLanguage.english: 'All',
      PassengerLanguage.french: 'Tous',
      PassengerLanguage.kinyarwanda: 'Byose',
      PassengerLanguage.swahili: 'Zote',
      PassengerLanguage.spanish: 'Todos',
    },
    'common.clear': {
      PassengerLanguage.english: 'Clear',
      PassengerLanguage.french: 'Effacer',
      PassengerLanguage.kinyarwanda: 'Siba',
      PassengerLanguage.swahili: 'Futa',
      PassengerLanguage.spanish: 'Limpiar',
    },
    'common.clearAll': {
      PassengerLanguage.english: 'Clear all',
      PassengerLanguage.french: 'Tout effacer',
      PassengerLanguage.kinyarwanda: 'Siba byose',
      PassengerLanguage.swahili: 'Futa vyote',
      PassengerLanguage.spanish: 'Limpiar todo',
    },
    'common.new': {
      PassengerLanguage.english: 'New',
      PassengerLanguage.french: 'Nouveau',
      PassengerLanguage.kinyarwanda: 'Bishya',
      PassengerLanguage.swahili: 'Mpya',
      PassengerLanguage.spanish: 'Nuevo',
    },
    'notifications.title': {
      PassengerLanguage.english: 'Notifications',
      PassengerLanguage.french: 'Notifications',
      PassengerLanguage.kinyarwanda: 'Amatangazo',
      PassengerLanguage.swahili: 'Arifa',
      PassengerLanguage.spanish: 'Notificaciones',
    },
    'notifications.unread': {
      PassengerLanguage.english: '{count} unread',
      PassengerLanguage.french: '{count} non lus',
      PassengerLanguage.kinyarwanda: '{count} zitasomwe',
      PassengerLanguage.swahili: '{count} hazijasomwa',
      PassengerLanguage.spanish: '{count} sin leer',
    },
    'notifications.markAllRead': {
      PassengerLanguage.english: 'Mark all read',
      PassengerLanguage.french: 'Tout marquer lu',
      PassengerLanguage.kinyarwanda: 'Byose byasomwe',
      PassengerLanguage.swahili: 'Weka vyote vimesomwa',
      PassengerLanguage.spanish: 'Marcar todo leido',
    },
    'notifications.filterUnread': {
      PassengerLanguage.english: 'Unread',
      PassengerLanguage.french: 'Non lus',
      PassengerLanguage.kinyarwanda: 'Bitasomwe',
      PassengerLanguage.swahili: 'Hazijasomwa',
      PassengerLanguage.spanish: 'Sin leer',
    },
    'notifications.clearActioned': {
      PassengerLanguage.english: 'Clear actioned',
      PassengerLanguage.french: 'Effacer les traitees',
      PassengerLanguage.kinyarwanda: 'Siba ibyakozweho',
      PassengerLanguage.swahili: 'Futa vilivyoshughulikiwa',
      PassengerLanguage.spanish: 'Limpiar las gestionadas',
    },
    'notifications.markRead': {
      PassengerLanguage.english: 'Mark read',
      PassengerLanguage.french: 'Marquer comme lu',
      PassengerLanguage.kinyarwanda: 'Shyira ku byasomwe',
      PassengerLanguage.swahili: 'Weka imesomwa',
      PassengerLanguage.spanish: 'Marcar leido',
    },
    'notifications.delete': {
      PassengerLanguage.english: 'Delete',
      PassengerLanguage.french: 'Supprimer',
      PassengerLanguage.kinyarwanda: 'Siba',
      PassengerLanguage.swahili: 'Futa',
      PassengerLanguage.spanish: 'Eliminar',
    },
    'notifications.emptyTitle': {
      PassengerLanguage.english: 'No notifications found.',
      PassengerLanguage.french: 'Aucune notification trouvee.',
      PassengerLanguage.kinyarwanda: 'Nta menyesha ryabonetse.',
      PassengerLanguage.swahili: 'Hakuna arifa zilizopatikana.',
      PassengerLanguage.spanish: 'No se encontraron notificaciones.',
    },
    'notifications.justNow': {
      PassengerLanguage.english: 'Just now',
      PassengerLanguage.french: 'A l instant',
      PassengerLanguage.kinyarwanda: 'Ubu nonaha',
      PassengerLanguage.swahili: 'Sasa hivi',
      PassengerLanguage.spanish: 'Ahora mismo',
    },
    'notifications.minutesAgo': {
      PassengerLanguage.english: '{m} min ago',
      PassengerLanguage.french: 'Il y a {m} min',
      PassengerLanguage.kinyarwanda: 'Iminota {m} ishize',
      PassengerLanguage.swahili: 'Dakika {m} zilizopita',
      PassengerLanguage.spanish: 'Hace {m} min',
    },
    'notifications.hoursAgo': {
      PassengerLanguage.english: '{h} h ago',
      PassengerLanguage.french: 'Il y a {h} h',
      PassengerLanguage.kinyarwanda: 'Amasaha {h} ashize',
      PassengerLanguage.swahili: 'Masaa {h} yaliyopita',
      PassengerLanguage.spanish: 'Hace {h} h',
    },
    'notifications.daysAgo': {
      PassengerLanguage.english: '{d} d ago',
      PassengerLanguage.french: 'Il y a {d} j',
      PassengerLanguage.kinyarwanda: 'Iminsi {d} ishize',
      PassengerLanguage.swahili: 'Siku {d} zilizopita',
      PassengerLanguage.spanish: 'Hace {d} d',
    },
    'request.title': {
      PassengerLanguage.english: 'Request Immediate Trip',
      PassengerLanguage.french: 'Demander un trajet immediat',
      PassengerLanguage.kinyarwanda: 'Saba urugendo rwihuse',
      PassengerLanguage.swahili: 'Omba safari ya haraka',
      PassengerLanguage.spanish: 'Solicitar viaje inmediato',
    },
    'request.pickup': {
      PassengerLanguage.english: 'Pickup location',
      PassengerLanguage.french: 'Lieu de depart',
      PassengerLanguage.kinyarwanda: 'Aho bagufatira',
      PassengerLanguage.swahili: 'Mahali pa kuchukulia',
      PassengerLanguage.spanish: 'Lugar de recogida',
    },
    'request.dropoff': {
      PassengerLanguage.english: 'Dropoff location',
      PassengerLanguage.french: 'Lieu de destination',
      PassengerLanguage.kinyarwanda: 'Aho ujya',
      PassengerLanguage.swahili: 'Mahali pa kushuka',
      PassengerLanguage.spanish: 'Lugar de destino',
    },
    'request.fare': {
      PassengerLanguage.english: 'Fare',
      PassengerLanguage.french: 'Tarif',
      PassengerLanguage.kinyarwanda: 'Igiciro',
      PassengerLanguage.swahili: 'Nauli',
      PassengerLanguage.spanish: 'Tarifa',
    },
    'request.submit': {
      PassengerLanguage.english: 'Send Request',
      PassengerLanguage.french: 'Envoyer la demande',
      PassengerLanguage.kinyarwanda: 'Ohereza ubusabe',
      PassengerLanguage.swahili: 'Tuma ombi',
      PassengerLanguage.spanish: 'Enviar solicitud',
    },
    'request.sending': {
      PassengerLanguage.english: 'Sending...',
      PassengerLanguage.french: 'Envoi...',
      PassengerLanguage.kinyarwanda: 'Birimo koherezwa...',
      PassengerLanguage.swahili: 'Inatuma...',
      PassengerLanguage.spanish: 'Enviando...',
    },
    'request.onlineDrivers': {
      PassengerLanguage.english: 'Online Drivers',
      PassengerLanguage.french: 'Chauffeurs en ligne',
      PassengerLanguage.kinyarwanda: 'Abashoferi bari online',
      PassengerLanguage.swahili: 'Madereva waliopo mtandaoni',
      PassengerLanguage.spanish: 'Conductores en linea',
    },
    'request.noDrivers': {
      PassengerLanguage.english: 'No online drivers right now.',
      PassengerLanguage.french: 'Aucun chauffeur en ligne pour le moment.',
      PassengerLanguage.kinyarwanda: 'Nta mushoferi uri online ubu.',
      PassengerLanguage.swahili: 'Hakuna dereva mtandaoni kwa sasa.',
      PassengerLanguage.spanish: 'No hay conductores en linea ahora.',
    },
    'request.submitted': {
      PassengerLanguage.english: 'Ride request submitted.',
      PassengerLanguage.french: 'Demande de trajet envoyee.',
      PassengerLanguage.kinyarwanda: 'Ubusabe bw urugendo bwoherejwe.',
      PassengerLanguage.swahili: 'Ombi la safari limetumwa.',
      PassengerLanguage.spanish: 'Solicitud de viaje enviada.',
    },
    'request.currentStatus': {
      PassengerLanguage.english: 'Current status',
      PassengerLanguage.french: 'Statut actuel',
      PassengerLanguage.kinyarwanda: 'Imiterere y ubu',
      PassengerLanguage.swahili: 'Hali ya sasa',
      PassengerLanguage.spanish: 'Estado actual',
    },
    'request.route': {
      PassengerLanguage.english: 'Route',
      PassengerLanguage.french: 'Itineraire',
      PassengerLanguage.kinyarwanda: 'Inzira',
      PassengerLanguage.swahili: 'Njia',
      PassengerLanguage.spanish: 'Ruta',
    },
    'request.noActive': {
      PassengerLanguage.english: 'No active immediate request yet.',
      PassengerLanguage.french:
          'Aucune demande immediate active pour le moment.',
      PassengerLanguage.kinyarwanda: 'Nta busabe bwihuse bukora ubu.',
      PassengerLanguage.swahili: 'Hakuna ombi la haraka linaloendelea bado.',
      PassengerLanguage.spanish: 'No hay solicitud inmediata activa aun.',
    },
    'request.pickDriverError': {
      PassengerLanguage.english: 'Please select a driver.',
      PassengerLanguage.french: 'Veuillez selectionner un chauffeur.',
      PassengerLanguage.kinyarwanda: 'Hitamo umushoferi.',
      PassengerLanguage.swahili: 'Tafadhali chagua dereva.',
      PassengerLanguage.spanish: 'Selecciona un conductor.',
    },
    'request.locationRequired': {
      PassengerLanguage.english: 'Pickup and dropoff are required.',
      PassengerLanguage.french:
          'Les emplacements de depart et destination sont requis.',
      PassengerLanguage.kinyarwanda: 'Aho bagufatira n aho ujya birasabwa.',
      PassengerLanguage.swahili:
          'Mahali pa kuchukulia na pa kushuka vinahitajika.',
      PassengerLanguage.spanish: 'La recogida y el destino son obligatorios.',
    },
    'request.fareError': {
      PassengerLanguage.english: 'Please enter a valid fare.',
      PassengerLanguage.french: 'Veuillez saisir un tarif valide.',
      PassengerLanguage.kinyarwanda: 'Andika igiciro cyemewe.',
      PassengerLanguage.swahili: 'Tafadhali weka nauli halali.',
      PassengerLanguage.spanish: 'Ingresa una tarifa valida.',
    },
    'request.seats': {
      PassengerLanguage.english: 'Seats',
      PassengerLanguage.french: 'Places',
      PassengerLanguage.kinyarwanda: 'Intebe',
      PassengerLanguage.swahili: 'Viti',
      PassengerLanguage.spanish: 'Asientos',
    },
    'request.rideType': {
      PassengerLanguage.english: 'Ride type',
      PassengerLanguage.french: 'Type de trajet',
      PassengerLanguage.kinyarwanda: 'Ubwoko bw urugendo',
      PassengerLanguage.swahili: 'Aina ya safari',
      PassengerLanguage.spanish: 'Tipo de viaje',
    },
    'rideType.economy': {
      PassengerLanguage.english: 'Economy',
      PassengerLanguage.french: 'Economique',
      PassengerLanguage.kinyarwanda: 'Bisanzwe',
      PassengerLanguage.swahili: 'Kawaida',
      PassengerLanguage.spanish: 'Economico',
    },
    'rideType.premium': {
      PassengerLanguage.english: 'Premium',
      PassengerLanguage.french: 'Premium',
      PassengerLanguage.kinyarwanda: 'Premium',
      PassengerLanguage.swahili: 'Premium',
      PassengerLanguage.spanish: 'Premium',
    },
    'rideType.bike': {
      PassengerLanguage.english: 'Bike',
      PassengerLanguage.french: 'Moto',
      PassengerLanguage.kinyarwanda: 'Moto',
      PassengerLanguage.swahili: 'Pikipiki',
      PassengerLanguage.spanish: 'Moto',
    },
    'request.seatRangeError': {
      PassengerLanguage.english: 'Seats must be between 1 and 8.',
      PassengerLanguage.french: 'Le nombre de places doit etre entre 1 et 8.',
      PassengerLanguage.kinyarwanda: 'Intebe zigomba kuba hagati ya 1 na 8.',
      PassengerLanguage.swahili: 'Viti lazima viwe kati ya 1 na 8.',
      PassengerLanguage.spanish: 'Los asientos deben estar entre 1 y 8.',
    },
    'request.tripIdMissing': {
      PassengerLanguage.english:
          'No trip id returned by backend. Please try again.',
      PassengerLanguage.french:
          'Aucun identifiant de trajet retourne par le backend. Reessayez.',
      PassengerLanguage.kinyarwanda:
          'Nta nimero y urugendo yagaruwe na backend. Ongera ugerageze.',
      PassengerLanguage.swahili:
          'Hakuna trip id iliyorejeshwa na backend. Jaribu tena.',
      PassengerLanguage.spanish:
          'No se devolvio id de viaje desde backend. Intentalo de nuevo.',
    },
    'common.retry': {
      PassengerLanguage.english: 'Retry',
      PassengerLanguage.french: 'Reessayer',
      PassengerLanguage.kinyarwanda: 'Ongera ugerageze',
      PassengerLanguage.swahili: 'Jaribu tena',
      PassengerLanguage.spanish: 'Reintentar',
    },
    'edit.fullName': {
      PassengerLanguage.english: 'Full Name',
      PassengerLanguage.french: 'Nom complet',
      PassengerLanguage.kinyarwanda: 'Amazina yose',
      PassengerLanguage.swahili: 'Jina kamili',
      PassengerLanguage.spanish: 'Nombre completo',
    },
    'edit.email': {
      PassengerLanguage.english: 'Email',
      PassengerLanguage.french: 'Email',
      PassengerLanguage.kinyarwanda: 'Imeyili',
      PassengerLanguage.swahili: 'Barua pepe',
      PassengerLanguage.spanish: 'Correo',
    },
    'edit.phone': {
      PassengerLanguage.english: 'Phone Number',
      PassengerLanguage.french: 'Numero de telephone',
      PassengerLanguage.kinyarwanda: 'Numero ya telefone',
      PassengerLanguage.swahili: 'Namba ya simu',
      PassengerLanguage.spanish: 'Numero de telefono',
    },
    'edit.update': {
      PassengerLanguage.english: 'Update Profile',
      PassengerLanguage.french: 'Mettre a jour le profil',
      PassengerLanguage.kinyarwanda: 'Vugurura umwirondoro',
      PassengerLanguage.swahili: 'Sasisha wasifu',
      PassengerLanguage.spanish: 'Actualizar perfil',
    },
    'edit.tapCamera': {
      PassengerLanguage.english: 'Tap camera icon to change photo',
      PassengerLanguage.french: 'Touchez l icone camera pour changer la photo',
      PassengerLanguage.kinyarwanda:
          'Kanda ku kimenyetso cya kamera uhindure ifoto',
      PassengerLanguage.swahili: 'Gusa ikoni ya kamera kubadilisha picha',
      PassengerLanguage.spanish: 'Toca el icono de camara para cambiar foto',
    },
    'edit.updating': {
      PassengerLanguage.english: 'Updating...',
      PassengerLanguage.french: 'Mise a jour...',
      PassengerLanguage.kinyarwanda: 'Biravugururwa...',
      PassengerLanguage.swahili: 'Inasasishwa...',
      PassengerLanguage.spanish: 'Actualizando...',
    },
    'rate.howWasExperience': {
      PassengerLanguage.english: 'How was your experience?',
      PassengerLanguage.french: 'Comment etait votre experience?',
      PassengerLanguage.kinyarwanda: 'Ubunararibonye bwawe bwari bumeze gute?',
      PassengerLanguage.swahili: 'Uzoefu wako ulikuwaje?',
      PassengerLanguage.spanish: 'Como fue tu experiencia?',
    },
    'rate.feedbackHint': {
      PassengerLanguage.english: 'Tell us what we can improve...',
      PassengerLanguage.french: 'Dites-nous ce que nous pouvons ameliorer...',
      PassengerLanguage.kinyarwanda: 'Tubwire icyo twanoza...',
      PassengerLanguage.swahili: 'Tuambie nini tuboreshe...',
      PassengerLanguage.spanish: 'Dinos que podemos mejorar...',
    },
    'rate.submit': {
      PassengerLanguage.english: 'Submit Review',
      PassengerLanguage.french: 'Envoyer l avis',
      PassengerLanguage.kinyarwanda: 'Ohereza Isubiramo',
      PassengerLanguage.swahili: 'Wasilisha Maoni',
      PassengerLanguage.spanish: 'Enviar resena',
    },
    'rate.thanks': {
      PassengerLanguage.english: 'Thank you for helping improve RideConnect.',
      PassengerLanguage.french: 'Merci de nous aider a ameliorer RideConnect.',
      PassengerLanguage.kinyarwanda: 'Murakoze kudufasha kunoza RideConnect.',
      PassengerLanguage.swahili: 'Asante kwa kusaidia kuboresha RideConnect.',
      PassengerLanguage.spanish: 'Gracias por ayudarnos a mejorar RideConnect.',
    },
    'help.q1': {
      PassengerLanguage.english: 'How do I cancel a ride?',
      PassengerLanguage.french: 'Comment annuler un trajet?',
      PassengerLanguage.kinyarwanda: 'Nakora nte ngo mpagarike urugendo?',
      PassengerLanguage.swahili: 'Ninawezaje kughairi safari?',
      PassengerLanguage.spanish: 'Como cancelo un viaje?',
    },
    'help.a1': {
      PassengerLanguage.english:
          'Open your active trip and tap Cancel before driver arrival.',
      PassengerLanguage.french:
          'Ouvrez le trajet actif et appuyez sur Annuler avant l arrivee.',
      PassengerLanguage.kinyarwanda:
          'Fungura urugendo rukora uhite ukanda Hagarika mbere y uko umushoferi agera.',
      PassengerLanguage.swahili:
          'Fungua safari yako inayoendelea kisha uguse Ghairi kabla dereva hajafika.',
      PassengerLanguage.spanish:
          'Abre tu viaje activo y pulsa Cancelar antes de que llegue el conductor.',
    },
    'help.q2': {
      PassengerLanguage.english: 'How is fare calculated?',
      PassengerLanguage.french: 'Comment le tarif est-il calcule?',
      PassengerLanguage.kinyarwanda: 'Igiciro cy urugendo kibarwa gute?',
      PassengerLanguage.swahili: 'Nauli inahesabiwaje?',
      PassengerLanguage.spanish: 'Como se calcula la tarifa?',
    },
    'help.a2': {
      PassengerLanguage.english:
          'Fare depends on distance, time, demand, and selected ride type.',
      PassengerLanguage.french:
          'Le tarif depend de la distance, du temps, de la demande et du type choisi.',
      PassengerLanguage.kinyarwanda:
          'Igiciro gishingira ku ntera, igihe, ubusabe n ubwoko bw urugendo wahisemo.',
      PassengerLanguage.swahili:
          'Nauli hutegemea umbali, muda, mahitaji na aina ya safari uliyochagua.',
      PassengerLanguage.spanish:
          'La tarifa depende de distancia, tiempo, demanda y tipo de viaje.',
    },
    'help.q3': {
      PassengerLanguage.english: 'How do I report an issue?',
      PassengerLanguage.french: 'Comment signaler un probleme?',
      PassengerLanguage.kinyarwanda: 'Nakora nte ngo menyeshe ikibazo?',
      PassengerLanguage.swahili: 'Ninaripotije tatizo vipi?',
      PassengerLanguage.spanish: 'Como reporto un problema?',
    },
    'help.a3': {
      PassengerLanguage.english:
          'Use Contact Support below and include trip details.',
      PassengerLanguage.french:
          'Utilisez Contacter le support ci-dessous et ajoutez les details du trajet.',
      PassengerLanguage.kinyarwanda:
          'Koresha Kuvugisha ubufasha hasi kandi ushyiremo amakuru y urugendo.',
      PassengerLanguage.swahili:
          'Tumia Wasiliana na Msaada hapa chini na uweke maelezo ya safari.',
      PassengerLanguage.spanish:
          'Usa Contactar Soporte abajo e incluye los detalles del viaje.',
    },
    'help.contact': {
      PassengerLanguage.english: 'Contact Support',
      PassengerLanguage.french: 'Contacter le support',
      PassengerLanguage.kinyarwanda: 'Vugisha ubufasha',
      PassengerLanguage.swahili: 'Wasiliana na msaada',
      PassengerLanguage.spanish: 'Contactar soporte',
    },
    'help.startChat': {
      PassengerLanguage.english: 'Start in-app support chat',
      PassengerLanguage.french: 'Demarrer le chat de support',
      PassengerLanguage.kinyarwanda: 'Tangira ikiganiro cy ubufasha',
      PassengerLanguage.swahili: 'Anza gumzo la msaada ndani ya app',
      PassengerLanguage.spanish: 'Iniciar chat de soporte en la app',
    },
    'help.emailSupport': {
      PassengerLanguage.english: 'Email Support',
      PassengerLanguage.french: 'Support email',
      PassengerLanguage.kinyarwanda: 'Ubufasha kuri imeyili',
      PassengerLanguage.swahili: 'Msaada kwa barua pepe',
      PassengerLanguage.spanish: 'Soporte por correo',
    },
    'help.callSupport': {
      PassengerLanguage.english: 'Call Support',
      PassengerLanguage.french: 'Appeler le support',
      PassengerLanguage.kinyarwanda: 'Hamagara ubufasha',
      PassengerLanguage.swahili: 'Piga msaada',
      PassengerLanguage.spanish: 'Llamar soporte',
    },
    'ride.prefRideType': {
      PassengerLanguage.english: 'Preferred Ride Type',
      PassengerLanguage.french: 'Type de trajet prefere',
      PassengerLanguage.kinyarwanda: 'Ubwoko bw urugendo ukunda',
      PassengerLanguage.swahili: 'Aina ya safari unayopendelea',
      PassengerLanguage.spanish: 'Tipo de viaje preferido',
    },
    'ride.tripUpdates': {
      PassengerLanguage.english: 'Trip Updates Notifications',
      PassengerLanguage.french: 'Notifications des mises a jour du trajet',
      PassengerLanguage.kinyarwanda: 'Amatangazo y ivugurura ry urugendo',
      PassengerLanguage.swahili: 'Arifa za masasisho ya safari',
      PassengerLanguage.spanish: 'Notificaciones de actualizacion del viaje',
    },
    'ride.promoNotifications': {
      PassengerLanguage.english: 'Promotional Notifications',
      PassengerLanguage.french: 'Notifications promotionnelles',
      PassengerLanguage.kinyarwanda: 'Amatangazo y ubukangurambaga',
      PassengerLanguage.swahili: 'Arifa za matangazo',
      PassengerLanguage.spanish: 'Notificaciones promocionales',
    },
    'ride.quietMode': {
      PassengerLanguage.english: 'Quiet Mode',
      PassengerLanguage.french: 'Mode silencieux',
      PassengerLanguage.kinyarwanda: 'Uburyo butuje',
      PassengerLanguage.swahili: 'Hali tulivu',
      PassengerLanguage.spanish: 'Modo silencioso',
    },
    'ride.defaultPickup': {
      PassengerLanguage.english: 'Default Pickup Location',
      PassengerLanguage.french: 'Lieu de prise en charge par defaut',
      PassengerLanguage.kinyarwanda: 'Ahantu hasanzwe hafatirwa',
      PassengerLanguage.swahili: 'Mahali chaguomsingi pa kuchukulia',
      PassengerLanguage.spanish: 'Ubicacion predeterminada de recogida',
    },
    'ride.savePreferences': {
      PassengerLanguage.english: 'Save Preferences',
      PassengerLanguage.french: 'Enregistrer les preferences',
      PassengerLanguage.kinyarwanda: 'Bika ibyifuzo',
      PassengerLanguage.swahili: 'Hifadhi mapendeleo',
      PassengerLanguage.spanish: 'Guardar preferencias',
    },
    'payment.addMethod': {
      PassengerLanguage.english: 'Add New Payment Method',
      PassengerLanguage.french: 'Ajouter un moyen de paiement',
      PassengerLanguage.kinyarwanda: 'Ongeraho uburyo bwo kwishyura',
      PassengerLanguage.swahili: 'Ongeza njia mpya ya malipo',
      PassengerLanguage.spanish: 'Agregar nuevo metodo de pago',
    },
  };

  Future<void> init() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefKey) ?? 'en';
    languageNotifier.value = _byCode[code] ?? PassengerLanguage.english;
    _isInitialized = true;
  }

  Future<void> ensureInitialized() => init();

  String codeOf(PassengerLanguage language) => _codes[language] ?? 'en';

  PassengerLanguage get current => languageNotifier.value;

  String languageLabel(PassengerLanguage language) {
    return switch (language) {
      PassengerLanguage.english => 'English',
      PassengerLanguage.french => 'French',
      PassengerLanguage.kinyarwanda => 'Kinyarwanda',
      PassengerLanguage.swahili => 'Swahili',
      PassengerLanguage.spanish => 'Spanish',
    };
  }

  Future<void> setLanguage(PassengerLanguage language) async {
    languageNotifier.value = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, codeOf(language));
  }

  String t(String key, {Map<String, String>? args}) {
    final lang = languageNotifier.value;
    final localized =
        _tr[key]?[lang] ?? _tr[key]?[PassengerLanguage.english] ?? key;
    if (args == null || args.isEmpty) return localized;

    var resolved = localized;
    args.forEach((k, v) {
      resolved = resolved.replaceAll('{$k}', v);
    });
    return resolved;
  }
}
