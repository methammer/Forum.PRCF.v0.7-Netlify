    import { useState } from 'react';
    import { supabase } from '@/lib/supabaseClient';
    import { Button } from '@/components/ui/button';
    import {
      Dialog,
      DialogContent,
      DialogHeader,
      DialogTitle,
      DialogDescription,
      DialogFooter,
      DialogClose,
    } from '@/components/ui/dialog';
    import { Textarea } from '@/components/ui/textarea';
    import { Label } from '@/components/ui/label';
    import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
    import { useToast } from '@/hooks/use-toast';
    import { Loader2, Send } from 'lucide-react';
    import { useAuth } from '@/hooks/useAuth';

    type ContentType = 'post' | 'reply';
    const reportReasonCategories = ['SPAM', 'HARASSMENT', 'OFFENSIVE_CONTENT', 'RULES_VIOLATION', 'OTHER'] as const;
    type ReportReasonCategory = typeof reportReasonCategories[number];

    interface ReportModalProps {
      isOpen: boolean;
      onClose: () => void;
      contentType: ContentType;
      contentId: string;
    }

    const ReportModal: React.FC<ReportModalProps> = ({ isOpen, onClose, contentType, contentId }) => {
      const { toast } = useToast();
      const { authUser } = useAuth();
      const [reasonCategory, setReasonCategory] = useState<ReportReasonCategory | ''>('');
      const [reasonDetails, setReasonDetails] = useState('');
      const [isSubmitting, setIsSubmitting] = useState(false);

      const handleSubmitReport = async () => {
        if (!authUser) {
          toast({ title: "Erreur", description: "Vous devez être connecté pour signaler du contenu.", variant: "destructive" });
          return;
        }
        if (!reasonCategory) {
          toast({ title: "Erreur", description: "Veuillez sélectionner une catégorie de raison.", variant: "destructive" });
          return;
        }
        if (reasonCategory === 'OTHER' && !reasonDetails.trim()) {
          toast({ title: "Erreur", description: "Veuillez fournir des détails pour la catégorie 'Autre'.", variant: "destructive" });
          return;
        }

        setIsSubmitting(true);
        try {
          const reportData: any = {
            reporter_user_id: authUser.id,
            reason_category: reasonCategory,
            reason_details: reasonDetails.trim() || null,
          };

          if (contentType === 'post') {
            reportData.reported_post_id = contentId;
          } else if (contentType === 'reply') {
            reportData.reported_reply_id = contentId;
          }

          const { error } = await supabase.from('forum_reports').insert(reportData);

          if (error) throw error;

          toast({
            title: "Signalement envoyé",
            description: "Merci, votre signalement a été soumis à notre équipe de modération.",
            className: "bg-green-500 text-white dark:bg-green-700",
          });
          onClose();
          setReasonCategory('');
          setReasonDetails('');
        } catch (error: any) {
          console.error("Error submitting report:", error);
          toast({
            title: "Erreur de signalement",
            description: error.message || "Une erreur est survenue lors de l'envoi de votre signalement.",
            variant: "destructive",
          });
        } finally {
          setIsSubmitting(false);
        }
      };

      return (
        <Dialog open={isOpen} onOpenChange={onClose}>
          <DialogContent className="sm:max-w-[425px] dark:bg-gray-800">
            <DialogHeader>
              <DialogTitle className="dark:text-white">Signaler le contenu</DialogTitle>
              <DialogDescription className="dark:text-gray-300">
                Aidez-nous à maintenir une communauté sûre et respectueuse.
                Votre signalement est anonyme pour l'auteur du contenu.
              </DialogDescription>
            </DialogHeader>
            <div className="grid gap-4 py-4">
              <div className="grid grid-cols-4 items-center gap-4">
                <Label htmlFor="reasonCategory" className="text-right dark:text-gray-200">
                  Raison
                </Label>
                <Select
                  value={reasonCategory}
                  onValueChange={(value) => setReasonCategory(value as ReportReasonCategory)}
                >
                  <SelectTrigger className="col-span-3 dark:bg-gray-700 dark:text-white dark:border-gray-600">
                    <SelectValue placeholder="Sélectionnez une catégorie" />
                  </SelectTrigger>
                  <SelectContent className="dark:bg-gray-700 dark:text-white">
                    {reportReasonCategories.map(cat => (
                      <SelectItem key={cat} value={cat} className="dark:hover:bg-gray-600">
                        {cat.replace('_', ' ').toLowerCase().replace(/\b\w/g, l => l.toUpperCase())}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="grid grid-cols-4 items-center gap-4">
                <Label htmlFor="reasonDetails" className="text-right dark:text-gray-200">
                  Détails <span className="text-xs text-gray-500 dark:text-gray-400">(optionnel)</span>
                </Label>
                <Textarea
                  id="reasonDetails"
                  value={reasonDetails}
                  onChange={(e) => setReasonDetails(e.target.value)}
                  placeholder="Fournissez plus d'informations si nécessaire..."
                  className="col-span-3 min-h-[100px] dark:bg-gray-700 dark:text-white dark:placeholder-gray-400 dark:border-gray-600"
                />
              </div>
            </div>
            <DialogFooter>
              <DialogClose asChild>
                <Button variant="outline" className="dark:text-gray-300 dark:border-gray-600 dark:hover:bg-gray-700">Annuler</Button>
              </DialogClose>
              <Button onClick={handleSubmitReport} disabled={isSubmitting || !reasonCategory} className="bg-red-600 hover:bg-red-700 text-white">
                {isSubmitting ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <Send className="mr-2 h-4 w-4" />}
                Envoyer le signalement
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      );
    };

    export default ReportModal;
