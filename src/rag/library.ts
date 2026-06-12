export type RagSpace='commercial'|'development'|'content';
export type RagDocument={id:string;space:RagSpace;title:string;summary:string;tags:string[];source:string;updatedAt:string};
export const commercialSpace:RagDocument[]=[
 {id:'commercial-positioning',space:'commercial',title:'Позиционирование MED TIM',summary:'Профессиональный справочник для быстрого доступа к лекарствам, заболеваниям, статьям и клиническим калькуляторам.',tags:['product','positioning','doctors'],source:'internal',updatedAt:'2026-06-12'},
 {id:'commercial-model',space:'commercial',title:'Коммерческая модель',summary:'Базовый справочник открыт, подписка расширяет контент, командные функции и администрирование.',tags:['pricing','subscription','b2b'],source:'internal',updatedAt:'2026-06-12'}
];
export const developmentSpace:RagDocument[]=[
 {id:'dev-stack',space:'development',title:'Технический стек',summary:'Node.js, TypeScript, Express, Prisma, SQLite для локальной разработки и JWT-аутентификация.',tags:['node','typescript','prisma'],source:'repository',updatedAt:'2026-06-12'},
 {id:'dev-api',space:'development',title:'API-контракт',summary:'REST API: /api/auth, /api/drugs, /api/diseases, /api/articles, /api/calculators и /api/rag.',tags:['api','rest','routes'],source:'repository',updatedAt:'2026-06-12'}
];
export const contentSpace:RagDocument[]=[
 {id:'content-policy',space:'content',title:'Политика медицинского контента',summary:'Материалы носят справочный характер, требуют редакционной проверки, даты пересмотра и ссылки на источник.',tags:['medical','review','safety'],source:'editorial',updatedAt:'2026-06-12'},
 {id:'content-taxonomy',space:'content',title:'Таксономия',summary:'Контент разделён на препараты, заболевания, статьи и калькуляторы; поиск учитывает названия, коды и ключевые слова.',tags:['taxonomy','search','content'],source:'editorial',updatedAt:'2026-06-12'}
];
export const ragLibrary={commercial:commercialSpace,development:developmentSpace,content:contentSpace};
export function searchRag(query:string,space?:RagSpace){const q=query.trim().toLowerCase();const docs=space?ragLibrary[space]:Object.values(ragLibrary).flat();return !q?docs:docs.filter(d=>[d.title,d.summary,...d.tags].join(' ').toLowerCase().includes(q));}
